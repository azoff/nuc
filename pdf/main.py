import tempfile
import logging
import openai
import re
import pydantic
import os
import json
from typing import List
from fastapi import FastAPI
from urllib.request import urlretrieve
from pdfminer.high_level import extract_text

class Request(pydantic.BaseModel):
	url: str
	extra_context: str = ''

class ChunkRequest(Request):
	chunk_size: int = 512

class AskRequest(ChunkRequest):
	prompt: str

class AskJsonRequest(ChunkRequest):
	questions: dict
	decode: bool = True

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

@app.post("/chunks")
def chunks(req:ChunkRequest):
	chunks = download_pdf_and_extract_chunks(req.url, extra_context=req.extra_context, chunk_size=req.chunk_size)
	return { "chunks": chunks }

@app.post("/complete")
def complete(req:AskRequest):
	(completion, chunks) = download_pdf_and_create_completion(
		req.url, req.prompt, 
		extra_context=req.extra_context, 
		chunk_size=req.chunk_size
	)
	return { "completion": completion, "chunks": chunks }

@app.post("/ask")
def ask_json(req:AskJsonRequest):
	prompt = """
	Please provide the answer in a compact JSON format, do not prefix with 
	'Response: '. Ensure that every object in the tree is properly quoted and 
	decodable as JSON.
	Response schema:
		interface Answer {
			text: string,
			citation: number
		}
		interface Response \{
			[question_key: string]: Answer[]
		}
	Ensure all Answer object keys are properly quoted and decodable as JSON.
	
	Input Questions:
	""" + json.dumps(req.questions)
	(completion, chunks) = download_pdf_and_create_completion(
		req.url, prompt, 
		extra_context=req.extra_context, 
	)
	text = completion.choices[0].text
	answer = None
	
	if (req.decode):
		try:
			answer = json.loads(text)
		except json.JSONDecodeError:
			logging.error(f"Failed to decode response as JSON: {text}")
			raise
	else:
		answer = text

	return {
		"answer": answer,
		"chunks": chunks
	}

def download_pdf_and_extract_chunks(url: str, extra_context: str = '', chunk_size:int = 512) -> str:
	text = download_pdf_and_extract_text(url, extra_context=extra_context)
	return text_to_chunks(text, chunk_size=chunk_size)

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

def download_pdf_and_create_completion(url: str, prompt: str, extra_context: str = '', chunk_size:int =512):
	chunks = download_pdf_and_extract_chunks(url, extra_context=extra_context, chunk_size=chunk_size)
	wrapped_prompt = wrap_prompt(chunks, prompt)
	return (create_completions(wrapped_prompt), chunks) 

def wrap_prompt(chunks: List[str], question:str) -> str:
	search_results = '\n'.join(chunks)
	return f"""Instructions:
		Compose a comprehensive reply to the query using the search results given. All answers should be as short as possible.
		Cite each reference using the '[N]' notation referencing the matching search result (every result has this number at the beginning).
		Citation should be included with each answer. If the search results mention multiple subjects
		with the same name, create separate answers for each. Only include information found in the results and
		don't add any additional information. Make sure the answer is correct and don't output false content.
		Ignore outlier search results that have nothing to do with the question. Only answer what is asked and 
		respond in the format that the question asks. The answer should be short and concise. Answer step-by-step.

		Search Results:
		{search_results}

		Question: 
		{question}

		Answer:
	"""

def download_pdf(url, output_path):
	logging.info(f"Downloading PDF from {url} to {output_path}")
	pdf = urlretrieve(url, output_path)
	logging.info(f"PDF downloaded.")
	return pdf

def text_to_chunks(text:str, chunk_size:int = 512) -> List[str]:
	text = text.replace('\n', ' ')
	text = re.sub('\s+', ' ', text)
	text_toks = text.split(' ')
	chunks = []
	for i in range(0, len(text_toks), chunk_size):
		chunk = text_toks[i : i + chunk_size]
		chunks.append(f"{len(chunks)+1}. {' '.join(chunk)}")
	return chunks

def create_completions(prompt):
	openai.api_key = os.environ.get("OPENAI_API_KEY")
	logging.info(f"Creating completion...")
	completion = openai.Completion.create(
		engine="text-davinci-003",
		prompt=prompt,
		max_tokens=150,
		n=1,
		stop=None,
		temperature=0.7,
	)
	logging.info(f"Completion created: {completion}")
	return completion