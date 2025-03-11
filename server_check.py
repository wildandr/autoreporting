from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Flask server is running correctly!'

@app.route('/check')
def check():
    return 'Server check passed!'

if __name__ == '__main__':
    # Using the exact same port as your main app for testing
    app.run(debug=True, host='0.0.0.0', port=8502)
