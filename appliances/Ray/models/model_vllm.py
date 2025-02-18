from ray import serve
from fastapi import FastAPI
from typing import Dict
from ray.serve import Application
from vllm import LLM, SamplingParams
import os


app = FastAPI()

@serve.deployment
@serve.ingress(app)
class ChatBot:
    def __init__(self, model_id: str, token:str, temperature: float, system_prompt: str):
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
        self.model = LLM(
            model=model_id, max_model_len=2048, gpu_memory_utilization=0.5)
        self.temperature = temperature
        self.system_prompt = system_prompt
        self.nmessages_hist = 4
        self.messages = [
            {"role": "system", "content": self.system_prompt}]
        
    @app.post("/chat")
    def chat(self, text: str) -> str:
        """Endpoint to communicate with deployed LLM.
        Args:
            text (str): given user input.

        Returns:
            answer (str): response from the LLM.
        """
        self.messages.append(
            {"role": "user", "content": text})
    
        # Tokenize the text
        outputs = self.model.chat(
            self.messages,
            sampling_params=SamplingParams(
                temperature=self.temperature,
                max_tokens=1024),
            use_tqdm=False)

        # Run inference
        answer = outputs[0].outputs[0].text
        # Add to conversation and strip it to 4 messages
        self.messages.append(
            {"role": "assistant", "content": answer})
        self.messages = self.messages[-self.nmessages_hist*2:]
        return answer
    

def app_builder(args: Dict[str, str]) -> Application:
    return ChatBot.bind(args["model_id"], args['token'], args['temperature'], args['system_prompt'])