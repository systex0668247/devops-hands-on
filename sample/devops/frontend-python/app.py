import os
from flask import Flask
app = Flask(__name__)

hostname = os.environ.get('HOSTNAME') or 'unknown'

@app.route('/')
def index():
    return hostname


def backend_java():
    return ''

def backend_php():
    return ''

if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0')
