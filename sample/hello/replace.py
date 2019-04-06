import os,logging
from flask import Flask
app = Flask(__name__)

# logging setting
os.makedirs("logs", exist_ok=True)
logging.basicConfig(filename='logs/myapp.log',level=logging.DEBUG)

@app.route('/')
def hello_world():
    logging.info("Hello World~~~")
    return 'Replaced Hello World~~~'

if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0')
