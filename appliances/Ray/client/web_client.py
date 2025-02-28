import yaml
import sys
import requests

from flask import Flask, request, jsonify, render_template

# Load configuration
with open("config.yaml", "r") as config_file:
    config = yaml.safe_load(config_file)

app = Flask(__name__)

base_url = config["base_url"]

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/chat", methods=["POST"])
def chat():
    global api_endpoint

    user_input = request.json.get("message", "")

    response = requests.post(base_url, params={"text": user_input})
    message  = response.json()

    return jsonify({"response": message})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

