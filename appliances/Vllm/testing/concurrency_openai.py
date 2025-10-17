from openai import OpenAI
import time
import concurrent.futures
import sys


# Function to perform the completion call and measure response time
def call_api(model, client, task_id):
    # Start measuring time
    start_time = time.time()

    # Make the API call
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": "What is the capital of Spain?"}],
        )
    except Exception as e:
        # Handle any exception (e.g., API error)
        print(f"Task {task_id} failed with error: {e}")
        return None

    # Measure the response time
    response_time = time.time() - start_time


    # Output the response time for this specific task
    print(f"Task {task_id} completed in {response_time:.4f} seconds")
    print(f"Response: {response.choices[0].message.content}")
    return response_time

# Function to run multiple API calls concurrently
def run_concurrent_tasks(model, num_concurrent_tasks, client):
    # Using ThreadPoolExecutor to run multiple calls concurrently
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_concurrent_tasks) as executor:
        # Submit tasks to the executor
        futures = [executor.submit(call_api, model, client, i) for i in range(num_concurrent_tasks)]

        # Wait for all futures to complete and retrieve their results
        for future in concurrent.futures.as_completed(futures):
            # This will return the response time for each task when it finishes
            result = future.result()
            if result is not None:
                print(f"Response time: {result:.4f} seconds")
                print("-----------------")

if __name__ == "__main__":
    # Parse command-line arguments
    if len(sys.argv) < 4:
        print("Usage: python chat_client.py <API_ENDPOINT> <MODEL_NAME> <N_TASKS>")
        sys.exit(1)

    api_endpoint = sys.argv[1]
    model_name = sys.argv[2]
    ncalls = int(sys.argv[3])

    client = OpenAI(
        base_url=api_endpoint,
        api_key="nothing")

    # Run the concurrent tasks
    run_concurrent_tasks(model_name, ncalls, client)

