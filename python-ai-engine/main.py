import logging
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from typing import List, Optional
import json

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="EquiHire Intelligence Engine")

# --- Data Models ---

class TextPayload(BaseModel):
    text: str
    context: Optional[str] = "interview"

class Redaction(BaseModel):
    entity: str
    label: str
    score: float

class SanitizedResponse(BaseModel):
    original_text_length: int
    sanitized_text: str
    pii_detected: bool
    redactions: List[Redaction]
    # Future: technical_score: float

# --- Mock AI Models (BERT Firewall) ---

def mock_redact_pii(text: str):
    """
    Mock BERT-NER Redaction.
    In real implementation, this loads a finetuned BERT model.
    """
    logger.info("Running BERT Firewall (Redaction)...")
    
    redactions = []
    sanitized_text = text
    
    # Mock Entities to Redact
    replacements = {
        "Hasitha": ("[Before: Candidate]", "PER"), 
        "John Doe": ("[Candidate]", "PER"),
        "Google": ("[Company]", "ORG"),
        "Sabaragamuwa University": ("[University]", "ORG"),
        "Malabe": ("[Location]", "LOC"),
        "Colombo": ("[Location]", "LOC")
    }
    
    pii_found = False
    
    # Simple replacement logic (simulating NER)
    for key, (replacement, label) in replacements.items():
        if key in sanitized_text:
            sanitized_text = sanitized_text.replace(key, replacement)
            redactions.append(Redaction(entity=key, label=label, score=0.99))
            pii_found = True
            
    return sanitized_text, redactions, pii_found

# --- Endpoints ---

@app.get("/")
async def root():
    return {"status": "online", "service": "EquiHire Intelligence Engine", "mode": "Firewall"}

@app.post("/sanitize", response_model=SanitizedResponse)
async def sanitize_text(payload: TextPayload):
    """
    The Bias Firewall Endpoint.
    Receives raw text, runs BERT Redaction, and returns clean text.
    """
    try:
        # 1. Firewall: Redact PII
        sanitized_text, redactions, pii_found = mock_redact_pii(payload.text)
        
        # 2. Analysis (Async/Background)
        # In a real app, we would kick off a background task here to compute scores
        # without blocking the return of the sanitized text.
        
        logger.info(f"Sanitized: '{payload.text}' -> '{sanitized_text}'")
        
        return SanitizedResponse(
            original_text_length=len(payload.text),
            sanitized_text=sanitized_text,
            pii_detected=pii_found,
            redactions=redactions
        )

    except Exception as e:
        logger.error(f"Error processing text: {e}")
        raise HTTPException(status_code=500, detail=str(e))
