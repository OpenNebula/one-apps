#!/usr/bin/env bash
set -e

DEFAULT_VLLM_API_PORT="8000"
DEFAULT_BENCHMARK_RESULTS_DIR="/root/benchmark_results"

detect_gpus() {
    local num_gpus=0
    if command -v nvidia-smi >/dev/null 2>&1; then
        raw=$(nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | tr -d '[:space:]' || true)
        if [[ $raw =~ ^[0-9]+$ ]]; then
            num_gpus=$raw
        else
            printf 'Warning: nvidia-smi gpu parsing failed; assuming 0 GPUs\n'
        fi
    fi
    echo "$num_gpus"
}

# Retrieve appliance context environment variables
source "/var/run/one-context/one_env"

# Load parameters
model_id="${1:-$ONEAPP_VLLM_MODEL_ID}"
vllm_api_port="${2:-${ONEAPP_VLLM_API_PORT:-$DEFAULT_VLLM_API_PORT}}"
output_dir="${3:-$DEFAULT_BENCHMARK_RESULTS_DIR}"

if [ -z "$model_id" ]; then
    echo "Error: inference model id must be provided. Pass as arguments or set ONEAPP_VLLM_MODEL_ID in appliance context."
    echo "Usage: $0 <model-id> [api-port] [output-dir]"
    echo "  <model-id>      : Model ID to benchmark (required if not set in appliance context)"
    echo "  [api-port]      : Serving inference API port to benchmark (optional, defaults to $DEFAULT_VLLM_API_PORT)"
    echo "  [output-dir]   : Optional, defaults to $DEFAULT_BENCHMARK_RESULTS_DIR"
    exit 1
fi

# Detect GPUs and activate appropriate Python environment
num_gpus=$(detect_gpus)
if [ "$num_gpus" -gt 0 ]; then
    echo "GPUs detected: $num_gpus, using GPU environment."
    source "/root/vllm_gpu_env/bin/activate"
else
    echo "No GPUs detected, using CPU environment."
    source "/root/vllm_cpu_env/bin/activate"
fi

# Run the benchmark
echo "Running benchmark for model '$model_id' against API on port '$vllm_api_port'..."

install -o 0 -g 0 -m u=rwx,g=rx,o= -d "$output_dir"
output_path="$output_dir/$model_id.html"


guidellm benchmark \
  --target "http://localhost:$vllm_api_port" \
  --model "$model_id" \
  --rate-type sweep \
  --max-seconds 20 \
  --warmup-percent 0.1 \
  --output-path="$output_path" \
  --display-scheduler-stats \
  --data "prompt_tokens=512,output_tokens=256"

echo "Benchmark completed. Results saved to $output_path"
