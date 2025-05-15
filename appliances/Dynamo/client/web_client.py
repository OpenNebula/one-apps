#!/usr/bin/env python3
import yaml
import requests

from flask import Flask, request, jsonify, render_template
import sys

# Load configuration
with open("config.yaml", "r") as config_file:
    config = yaml.safe_load(config_file)

app = Flask(__name__)

base_url = config["base_url"]
model = config["model"]

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/chat", methods=["POST"])
def chat():
    global api_endpoint

    user_input = request.json.get("message", "")
    # create json data
    data = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": user_input
            }
        ],
        "stream": False,
        "max_tokens": 300
    }
    # convert data to json
    response = requests.post(base_url, json=data, headers={"Content-Type": "application/json"})
    #debug request
    print(f"Request URL: {response.url}")
    print(f"Request Headers: {response.request.headers}")
    print(f"Request Body: {response.request.body}")
    #debug response
    print(f"Response Status Code: {response.status_code}")
    print(f"Response Headers: {response.headers}")
    print(f"Response Body: {response.text}")
    # check if response is ok
    if response.status_code != 200:
        return jsonify({"error": "Failed to get a response from the server"}), 500

    message  = response.json()
    # access the field choices[0].message.content
    if "choices" in message and len(message["choices"]) > 0:
        message = message["choices"][0]["message"]["content"]

    print(f"Response JSON: {message}")

    return jsonify({"response": message})

if __name__ == "__main__":
    port = 5000 # Default port
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
            if port <= 1024 or port > 65535:
                raise ValueError
        except ValueError:
            print("Error: Port must be an integer greater than 1024 and less than 65536.")
            sys.exit(1)

    app.run(host="0.0.0.0", port=port, debug=True, use_reloader=False)

