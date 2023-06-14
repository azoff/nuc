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

class AskRequest(Request):
	prompt: str

class AskJsonRequest(Request):
	questions: dict
	decode: bool = True

logging.basicConfig(level=logging.INFO)

app = FastAPI()

@app.get("/")
def index():
	return {"status": "ready"}

@app.post("/text")
def text(req:Request):
	text = download_pdf_and_extract_text(req.url)
	return { "text": text }

@app.post("/chunks")
def chunks(req:Request):
	chunks = download_pdf_and_extract_chunks(req.url)
	return { "chunks": chunks }

@app.post("/complete")
def ask(req:AskRequest):
	(completion, chunks) = download_pdf_and_create_completion(req.url, req.prompt)
	return { "completion": completion, "chunks": chunks }

@app.post("/ask")
def ask_json(req:AskJsonRequest):
	prompt = """Please provide the answer in JSON format, ensure the entire response structure is 
	decodable as JSON, do not prefix with 'Response: ' and quote all keys:
	Response schema:
		interface Answer {
			text: string,
			citation: number
		}
		interface Response \{
			[question_key: string]: Answer[]
		}
	
	Input Questions:
	""" + json.dumps(req.questions, indent=4)
	(completion, chunks) = download_pdf_and_create_completion(req.url, prompt)
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

def download_pdf_and_extract_chunks(url: str) -> str:
	text = download_pdf_and_extract_text(url)
	return text_to_chunks(text)

def download_pdf_and_extract_text(url: str) -> str:
	text = None
	with tempfile.NamedTemporaryFile() as temp:
		download_pdf(url, temp.name)
		text = extract_text(temp.name)
	return text

def download_pdf_and_create_completion(url: str, prompt: str):
	chunks = download_pdf_and_extract_chunks(url)
	wrapped_prompt = wrap_prompt(chunks, prompt)
	return (create_completions(wrapped_prompt), chunks)

def wrap_prompt(chunks: List[str], question:str) -> str:
	search_results = '\n'.join(chunks)
	return f"""Instructions:
		Compose a comprehensive reply to the query using the search results given.
		Cite each reference using the '[N]' notation referencing the matching search result (every result has this number at the beginning).
		Citation should be included with each answer. If the search results mention multiple subjects
		with the same name, create separate answers for each. Only include information found in the results and
		don't add any additional information. Make sure the answer is correct and don't output false content.
		If a given answer does not have a source in the search results, simply state 'undefined'. Ignore outlier search results that 
		have nothing to do with the question. Only answer what is asked and respond in the format that the question asks. 
		The answer should be short and concise. Answer step-by-step.

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

def text_to_chunks(text:str) -> List[str]:
	text = text.replace('\n', ' ')
	text = re.sub('\s+', ' ', text)
	text_toks = text.split(' ')
	chunks = []
	for i in range(0, len(text_toks), 150):
		chunk = text_toks[i : i + 150]
		chunks.append(f"{len(chunks)+1}. {' '.join(chunk)}")
	return chunks

def create_completions(prompt):
	openai.api_key = os.environ.get("OPENAI_API_KEY")
	logging.info(f"Creating completion...")
	completion = openai.Completion.create(
		engine="text-davinci-003",
		prompt=prompt,
		max_tokens=512,
		n=1,
		stop=None,
		temperature=0.7,
	)
	logging.info(f"Completion created: {completion}")
	return completion