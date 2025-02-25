import ray
from ray import serve
from fastapi import FastAPI
from transformers import pipeline, AutoModelForCausalLM, AutoTokenizer
from ray.serve.handle import DeploymentHandle
from typing import Dict
from ray.serve import Application
import torch
import re
import asyncio


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
        # Load model
        self.device = "cuda:0" if torch.cuda.is_available() else "cpu"
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_id, token=token)
        self.model = AutoModelForCausalLM.from_pretrained(
            model_id, token=token).to(self.device)
        self.temperature = temperature
        self.system_prompt = system_prompt
        self.messages = [
                    {"role": "system", "content": self.system_prompt}]
        self.nmessages_hist = 4
        # Check if there is chat_template
        if self.tokenizer.chat_template is None:
            self.tokenizer.chat_template = """
                {% if not add_generation_prompt is defined %}
                    {% set add_generation_prompt = false %}
                {% endif %}
                {% for message in messages %}
                    {{ '<|im_start|>' + message['role'] + '\n' + message['content'] + '<|im_end|>\n' }}
                {% endfor %}
                {% if add_generation_prompt %}
                    {{ '<|im_start|>assistant\n' }}
                {% endif %}
            """

    @app.post("/chat")
    async def chat(self, text: str) -> str:
        """Endpoint to communicate with deployed LLM.
        Args:
            text (str): given user input.

        Returns:
            answer (str): response from the LLM.
        """
        self.messages.append(
            {"role": "user", "content": text})

        # Tokenize the text
        chat = self.tokenizer.apply_chat_template(
            self.messages, tokenize=False, add_generation_prompt=True, return_tensors="pt")
        input_tokens = self.tokenizer(chat, return_tensors="pt").to(self.device)

        # Run inference
        output = self.model.generate(
            **input_tokens, 
            max_new_tokens=1024)
        
        # Decode output tokens into text
        prompt_length = input_tokens['input_ids'].shape[1]
        output = self.tokenizer.decode(output[0][prompt_length:])
        answer = re.sub(r'<.*?>', '', output)

        # Add it to conversation
        self.messages.append(
            {"role": "assistant", "content": answer})
        self.messages = self.messages[-self.nmessages_hist*2:]
        return answer
    

def app_builder(args: Dict[str, str]) -> Application:
    return ChatBot.bind(args["model_id"], args['token'], args['temperature'], args['system_prompt'])