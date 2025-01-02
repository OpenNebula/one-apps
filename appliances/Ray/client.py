import sys
import requests

def chat(api_endpoint):
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
            response = requests.post(api_endpoint, params={"text": user_input})
            response.raise_for_status()  # Raise an error for HTTP issues

            # Parse and print the server's response
            server_response = response.json()
            print(f"Server: {server_response}")
        except requests.exceptions.RequestException as e:
            print(f"Error: {e}")
        except ValueError:
            print("Error: Invalid response from server (not JSON).")

if __name__ == "__main__":
    # Check if the API endpoint is provided as an argument
    if len(sys.argv) < 2:
        print("Usage: python chat_client.py <API_ENDPOINT>")
        sys.exit(1)

    api_endpoint = sys.argv[1]
    chat(api_endpoint)

