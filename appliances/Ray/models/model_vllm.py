# Libraries
from ray import serve
from fastapi import FastAPI
from typing import Dict
from ray.serve import Application
from vllm import LLM, SamplingParams
import os
import asyncio
import torch

# App endpoint
app = FastAPI()

@serve.deployment
@serve.ingress(app)
class ChatBot:
    def __init__(
            self,
            model_id: str,
            token:str,
            temperature: float,
            system_prompt: str,
            max_new_tokens: int,
            quantization: int=0):
        """Default class for conversational chatbot using vLLM and Ray appliance.
        Args:
            model_id (str): HuggingFace model ID from the model that we want to deploy. 
            token (str): HuggingFace token to be used for authentication.
            temperature (str): temperature of the model, randomness.
            system_prompt (str): system prompt to define the behaviour of the LLM.

        Returns:
            None.
        """
        # Set-up token env. to download models
        os.environ["HF_TOKEN"] = token

        # Load model
        if quantization > 0:
            self.model = LLM(
                model=model_id, gpu_memory_utilization=0.8,
                tensor_parallel_size=torch.cuda.device_count(),
                quantization="bitsandbytes", load_format="bitsandbytes",
                dtype=torch.bfloat16)
        else:
            self.model = LLM(
                model=model_id, gpu_memory_utilization=0.8,
                tensor_parallel_size=torch.cuda.device_count(),
                dtype=torch.bfloat16)

        # Identify model params
        self.temperature = temperature
        self.system_prompt = system_prompt
        self.max_new_tokens = max_new_tokens

    @app.post("/chat")
    async def chat(
        self, text: str) -> str:
        """Endpoint to communicate with deployed LLM.
        Args:
            text (str): given user input.

        Returns:
            answer (str): response from the LLM.
        """
        messages = [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": text}]

        # Tokenize the text
        outputs = self.model.chat(
            messages,
            sampling_params=SamplingParams(
                temperature=self.temperature,
                max_tokens=self.max_new_tokens),
            use_tqdm=False)

        # Run inference
        answer = outputs[0].outputs[0].text
        return answer


def app_builder(args: Dict[str, str]) -> Application:
    return ChatBot.bind(
        args["model_id"],
        args.get('token', None),
        args['temperature'],
        args['system_prompt'],
        args['max_new_tokens'],
        args['quantization'])
