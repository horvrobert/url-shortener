from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy import create_engine, text
import random
import string
import os
import boto3
import json

app = FastAPI()

def get_db_url():
    secret_arn = os.getenv("DB_SECRET_ARN")
    
    if secret_arn:
        client = boto3.client("secretsmanager", region_name="eu-central-1")
        secret = client.get_secret_value(SecretId=secret_arn)
        creds = json.loads(secret["SecretString"])
        return f"postgresql://{creds['username']}:{creds['password']}@{creds['host']}:{creds['port']}/{creds['dbname']}"
    
    return os.getenv("DATABASE_URL")

engine = create_engine(get_db_url())

def init_db():
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS urls (
                id SERIAL PRIMARY KEY,
                short_code VARCHAR(10) UNIQUE NOT NULL,
                long_url TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        conn.commit()

@app.on_event("startup")
def startup():
    init_db()

class URLRequest(BaseModel):
    long_url: str

def generate_code():
    return ''.join(random.choices(string.ascii_letters + string.digits, k=6))

@app.post("/shorten")
def shorten_url(request: URLRequest):
    code = generate_code()
    with engine.connect() as conn:
        conn.execute(text(
            "INSERT INTO urls (short_code, long_url) VALUES (:code, :url)"
        ), {"code": code, "url": request.long_url})
        conn.commit()
    return {"short_code": code, "long_url": request.long_url}

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.get("/{code}")
def redirect_url(code: str):
    with engine.connect() as conn:
        result = conn.execute(text(
            "SELECT long_url FROM urls WHERE short_code = :code"
        ), {"code": code})
        row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Code not found")
    return RedirectResponse(url=row[0], status_code=301)