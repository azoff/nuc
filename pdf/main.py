import tempfile
import logging
import re
import pydantic
import os
import json
import tiktoken
from typing import List
from fastapi import FastAPI
from urllib.request import urlretrieve
from pdfminer.high_level import extract_text

class Request(pydantic.BaseModel):
	url: str
	extra_context: str = ''

class TruncateRequest(Request):
	max_tokens: int = 256
	model: str = "gpt-3.5-turbo"

logging.basicConfig(level=logging.INFO)

app = FastAPI()
cache = {}

@app.get("/")
def index():
	return {"status": "ok"}

@app.post("/text")
def text(req:Request):
	text = download_pdf_and_extract_text(req.url, extra_context=req.extra_context)
	return { "text": text }

@app.post("/truncate")
def truncate(req:TruncateRequest):
	text = download_pdf_and_truncate_text(
		req.url, 
		extra_context=req.extra_context, 
		max_tokens=req.max_tokens,
		model=req.model
	)
	return { "text": text }

def download_pdf_and_truncate_text(url: str, extra_context: str = '', max_tokens:int = 256, model:str = "gpt-3.5-turbo") -> str:
	text = download_pdf_and_extract_text(url, extra_context=extra_context)
	return truncate_text(text, max_tokens=max_tokens, model=model)

def download_pdf_and_extract_text(url: str, extra_context: str = '') -> str:
	
	global cache

	# hash the inputs into a cache key
	cache_key = str(hash((url, extra_context)))
	if (cache_key in cache and cache[cache_key] is not None):
		logging.info(f"Using cache for {url}...")
		return cache[cache_key]
	
	text = ''
	with tempfile.NamedTemporaryFile() as temp:
		download_pdf(url, temp.name)
		text = extract_text(temp.name)
	
	cache[cache_key] = f"{extra_context}{text}"
	return cache[cache_key]

def download_pdf(url, output_path):
	logging.info(f"Downloading PDF from {url} to {output_path}")
	pdf = urlretrieve(url, output_path)
	logging.info(f"PDF downloaded.")
	return pdf

def truncate_text(text:str, max_tokens:int = 256, model:str = "gpt-3.5-turbo") -> str:
	text = text.replace('\n', ' ')
	text = re.sub('[\s\W]([\S\w][\s\W])+', ' ', text)
	text = re.sub('\s+', ' ', text)
	encoding = tiktoken.encoding_for_model(model)
	tokens = encoding.encode(text)
	trim = max_tokens - len(tokens)
	if trim >= 0:
		return text
	return encoding.decode(tokens[:trim])
