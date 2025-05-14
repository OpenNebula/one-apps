# Libraries
from ray.serve.handle import DeploymentHandle
from ray.serve import Application
from ray import serve
from transformers import AutoModelForCausalLM, AutoTokenizer
from transformers import BitsAndBytesConfig
import torch
from fastapi import FastAPI, HTTPException
from typing import Dict, List, List, Optional
import asyncio
from pydantic import BaseModel
import time


# Define classes to use OpenAI API
class CompletionRequest(BaseModel):
    model: str
    prompt: str
    max_tokens: Optional[int] = 512
    temperature: Optional[float] = 0.1
class ChatMessage(BaseModel):
    role: str
    content: str
class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[ChatMessage]
    max_tokens: Optional[int] = 512
    temperature: Optional[float] = 0.1
    stream: Optional[bool] = False

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
            quantization: int=0):
        # Load model and tokenizer
        self.model_id = model_id
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_id, token=token)
        self.model = AutoModelForCausalLM.from_pretrained(
            model_id, token=token, device_map="auto")

    def _generate_completions(
            self, 
            prompt: str, 
            temperature: float, 
            max_tokens: int) -> dict:
        """Generates completions using the Hugging Face model."""
        # Apply chat template and tokenize
        input_tokens = self.tokenizer(
            prompt, return_tensors="pt").to(self.model.device)

        # Apply chat template and tokenize
        output = self.model.generate(
            input_tokens['input_ids'],
            attention_mask=input_tokens['attention_mask'],
            max_new_tokens=max_tokens,
            temperature=temperature,
            do_sample=True)

        # Decode output tokens into text
        return self.tokenizer.decode(output[0], skip_special_tokens=True)

    def _generate_chat_completions(
            self,
            messages: List[ChatMessage],
            temperature: float,
            max_tokens: int) -> dict:
        """Generates chat completions using the Hugging Face model."""
        # Apply chat template and tokenize
        chat_input = self.tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True, return_tensors="pt")
        input_tokens = self.tokenizer(
            chat_input, return_tensors="pt").to(self.model.device)

        # Run inference
        output = self.model.generate(
            input_tokens['input_ids'],
            attention_mask=input_tokens['attention_mask'],
            max_new_tokens=max_tokens,
            temperature=temperature,
            do_sample=True)

        # Decode output tokens into text
        prompt_length = input_tokens['input_ids'].shape[1]
        answer = self.tokenizer.decode(output[0][prompt_length:], skip_special_tokens=True)
        return answer

    # OpenAI compatible /v1/completions endpoint
    @app.post("/v1/completions")
    async def completions(self, request: CompletionRequest):
        try:
            generated_text = await asyncio.to_thread(
                self._generate_completions, request.prompt,
                request.temperature, request.max_tokens)
            return {
                "id": "111111",
                "object": "text_completion",
                "created": time.time(),  # Static timestamp for simplicity
                "model": request.model,
                "choices": [{"text": generated_text}]
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error during model inference: {str(e)}")

    # OpenAI compatible /v1/chat/completions endpoint
    @app.post("/v1/chat/completions")
    async def chat_completions(self, request: ChatCompletionRequest):
        try:
            # Generate the chat response using the local model
            generated_text = await asyncio.to_thread(
                self._generate_chat_completions, request.messages,
                request.temperature, request.max_tokens)

            return {
                "id": "11111",
                "object": "chat.completion",
                "created": time.time(),  # Static timestamp for simplicity
                "model": request.model,
                "choices": [{
                    "message": ChatMessage(role="assistant", content=generated_text)
                }]
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error during model inference: {str(e)}")


def app_builder(args: Dict[str, str]) -> Application:
    return ChatBot.bind(
        args["model_id"],
        args.get('token', None),
        args['quantization'])
