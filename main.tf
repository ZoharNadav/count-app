provider "aws" {
  region = "us-east-1"
  access_key = "access_key" #to change
  secret_key = "secret_key" # to change
}


resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
      name = "my-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.main.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id 
    }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
      description      = "SSH from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }

  ingress {
      description      = "HTTP from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      
    }

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }
}

resource "aws_network_interface" "foo" {
  subnet_id   = aws_subnet.main.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_ssh.id]
  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.foo.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_instance" "my-server" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key" #to change
  depends_on = [aws_eip.one]

  network_interface {
    network_interface_id = aws_network_interface.foo.id
    device_index = 0
  }
  
  provisioner "file" {
    source      = "/home/azureuser/home-test/for-docker" #to change
    destination = "/home/ubuntu"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/main-key.pem") #to change
      host        = self.public_ip
    }
  }
    user_data = <<-EOF
                  #!/bin/bash
                  sudo apt-get update
                  sudo apt-get -y install \
                  apt-transport-https \
                  ca-certificates \
                  curl \
                  gnupg \
                  lsb-release
                  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                  echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
                  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                  sudo apt-get update
                  sudo apt-get -y install docker-ce docker-ce-cli containerd.io
                  sudo groupadd docker
                  sudo usermod -aG docker $USER
                  sudo newgrp docker 
                  docker build --tag python-costum /home/ubuntu/for-docker
                  docker run -p 80:80 -d --name python-app python-costum 
                  EOF

            
}
