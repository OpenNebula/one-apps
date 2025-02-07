from ray import serve
from fastapi import FastAPI
from typing import Dict
from ray.serve import Application
from vllm import LLM, SamplingParams
import os

# include vllm in config.yaml for this configuration

app = FastAPI()

@serve.deployment
@serve.ingress(app)
class ChatBot:
    def __init__(self, model_id: str, token:str, temperature: float, system_prompt: str):
        # Set-up token env. to download models
        os.environ["HF_TOKEN"] = token

        # Load model
        self.model = LLM(model=model_id, max_model_len=5000)

        self.temperature   = temperature
        self.system_prompt = system_prompt

    @app.post("/chat")
    def chat(self, text: str) -> str:
        messages = [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": text}]

        # Tokenize the text
        outputs = self.model.chat(
            messages,
            sampling_params=SamplingParams(
                temperature=self.temperature,
                max_tokens=1024),
            use_tqdm=False)

        # Run inference
        answer = outputs[0].outputs[0].text
        return answer

def app_builder(args: Dict[str, str]) -> Application:
    return ChatBot.bind(args["model_id"], args['token'], args['temperature'], args['system_prompt'])
