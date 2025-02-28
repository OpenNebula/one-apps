import sys
import requests
from openai import OpenAI

# python3 client_openai localhost/v1

def chat(api_endpoint, model_name):

    client = OpenAI(
        base_url=api_endpoint,
        api_key="nothing")

    print("Chat interface started. Type 'exit' to quit.")
    while True:
        # Read user input
        user_input = input("You: ")

        # Check for exit condition
        if user_input.lower() == 'exit':
            print("Goodbye!")
            break

        try:
            # Send input to the server
            completion = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "user", "content": user_input}
                ]
            )

            # Parse and print the server's response
            response = completion.choices[0].message.content
            print(f"Server: {response}")
        except requests.exceptions.RequestException as e:
            print(f"Error: {e}")
        except ValueError:
            print("Error: Invalid response from server (not JSON).")

if __name__ == "__main__":
    # Check if the API endpoint is provided as an argument
    if len(sys.argv) < 3:
        print("Usage: python chat_client.py <API_ENDPOINT> <MODEL_NAME>")
        sys.exit(1)

    api_endpoint = sys.argv[1]
    model_name = sys.argv[2]
    chat(api_endpoint, model_name)