import flask
from flask import request, jsonify

app = flask.Flask(__name__)
app.config["DEBUG"] = True

# Create some test data for our catalog in the form of a list of dictionaries.
data = {
    "message": "Hello Deserve",
    "branches": "US, Pune, Bangalore",
    "containername": "Deserve"
}


@app.route('/')
def home():
    return '''<h1>Welcome to Deserve!</h1>'''


# A route to return all of the available entries in our catalog.
@app.route('/api/get', methods=['GET'])
def api_all():
    return jsonify(data)

app.run(host='0.0.0.0')
