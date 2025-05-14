# Libraries
from ray.serve.handle import DeploymentHandle
from ray.serve import Application
from ray import serve
from transformers import AutoModelForCausalLM, AutoTokenizer
from transformers import BitsAndBytesConfig
import torch
from fastapi import FastAPI
from typing import Dict
import re
import asyncio

# App endpoint
app = FastAPI()

# Quantization defs
bnb_config = {
    4: BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16),
    8: BitsAndBytesConfig(
        load_in_8bit=True,
        bnb_4bit_compute_dtype=torch.bfloat16)
}

@serve.deployment
@serve.ingress(app)
class ChatBot:
    def __init__(
            self,
            model_id: str,
            token: str,
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
            max_new_tokens (int): maximum number of tokens to be generated during inference.
            quantization (int): integer that reflects if quantization is applied or not.
                If the value is 4, 4 bit quantization will be applied, same as with value of 8.
        Returns:
            None.
        """
        # Load model and tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_id, token=token)
        if quantization > 0:
            self.model = AutoModelForCausalLM.from_pretrained(
                model_id, token=token, device_map="auto",
                quantization_config=bnb_config[quantization])
        else:
            self.model = AutoModelForCausalLM.from_pretrained(
                model_id, token=token, device_map="auto")

        # Identify model params
        self.temperature = temperature
        self.system_prompt = system_prompt
        self.max_new_tokens = max_new_tokens

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
    async def chat(
        self,
        text: str) -> str:
        """Endpoint to communicate with deployed LLM.
        Args:
            text (str): given user input.

        Returns:
            answer (str): response from the LLM.
        """
        # Include system prompt
        self.messages = [
           {"role": "system", "content": self.system_prompt},
           {"role": "user", "content": text}]

        # Apply chat template and tokenize
        chat = self.tokenizer.apply_chat_template(
            self.messages,
            tokenize=False,
            add_generation_prompt=True,
            return_tensors="pt")
        input_tokens = self.tokenizer(
            chat, return_tensors="pt").to(self.model.device)

        # Run inference
        output = self.model.generate(
            **input_tokens,
            max_new_tokens=self.max_new_tokens)

        # Decode output tokens into text
        prompt_length = input_tokens['input_ids'].shape[1]
        output = self.tokenizer.decode(output[0][prompt_length:])
        answer = re.sub(r'<.*?>', '', output)

        # Add it to conversation
        return answer


def app_builder(args: Dict[str, str]) -> Application:
    return ChatBot.bind(
        args["model_id"],
        args.get('token', None),
        args['temperature'],
        args['system_prompt'],
        args['max_new_tokens'],
        args['quantization'])