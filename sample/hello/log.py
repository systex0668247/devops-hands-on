import os,logging

# logging setting
os.makedirs("logs", exist_ok=True)
logging.basicConfig(filename='logs/myapp.log',level=logging.DEBUG)

if __name__ == '__main__':
    logging.info( os.environ.get('HOSTNAME') or 'unknown' )
