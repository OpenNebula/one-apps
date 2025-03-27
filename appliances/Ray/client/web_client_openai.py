import yaml
from flask import Flask, request, jsonify, render_template
from openai import OpenAI

# Load configuration
with open("config.yaml", "r") as config_file:
    config = yaml.safe_load(config_file)

app = Flask(__name__)

client = OpenAI(base_url=config["base_url"], api_key=config["api_key"])
model  = config["model"]
prompt = config["prompt"]

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/chat", methods=["POST"])
def chat():
    global client
    global model

    user_input = request.json.get("message", "")

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": user_input}],
        max_tokens=512,
        temperature=0.1
    )

    message = response.choices[0].message.content

    return jsonify({"response": message})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
