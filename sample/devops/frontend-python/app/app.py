from flask import Flask
from flask import render_template, json
import os, requests

app = Flask(__name__)

hostname       = os.environ.get('HOSTNAME') or 'unknown'

@app.route("/")
def index():
    return render_template('index.html', title="DevOps sample")

@app.route('/backend-java')
def backend_java():
    return requests.get('http://backend-java:8080/').text

@app.route('/backend-php')
def backend_php():
    return requests.get('http://backend-php/').text

if __name__ == '__main__':
    app.debug = True
    app.run(host='0.0.0.0', port=80)
