from flask import Flask
app = Flask(__name__)
num = 0 

@app.route('/')
def hello():
    global num
    num+=1
    return 'Hello, World!'
@app.route('/count')
def count():
    global num
    num2 = {"count":num}
    return num2
if __name__ == '__main__':
     app.run(host='0.0.0.0', port=80)
