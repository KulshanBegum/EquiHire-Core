# EquiHire-Core: The Real-Time Cognitive Bias Firewall

**"Evaluating Code, Not Context."**

EquiHire is an AI-driven intermediary layer for technical recruitment. It intercepts live audio from candidates during technical interviews, sanitizes their identity (voice, accent, and PII) in real-time using a hybrid microservices architecture, and presents recruiters with a purely semantic text stream. This ensures hiring decisions are based solely on technical merit, effectively acting as a firewall against unconscious bias.

---

## Table of Contents
- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [System Architecture](#system-architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Documentation](#documentation)
- [Project Structure](#project-structure)

---

## The Problem
Technical recruitment is plagued by unconscious biases that "Blind Hiring" tools fail to solve:
1.  **The Accent Penalty:** Candidates with non-native accents are subconsciously rated lower on technical competence.
2.  **Contextual Bias:** Hiring managers favor candidates from specific universities or demographics based on visual/auditory cues.
3.  **The "Black Box" Rejection:** Rejected candidates rarely receive explainable feedback on why they failed.

## The Solution
EquiHire replaces the video call with a **Sanitized Real-Time Data Stream**.
1.  **Audio Interception:** We capture the candidate's voice via Twilio Media Streams (or Browser WebSocket).
2.  **AI Sanitization (The Firewall):**
    -   **OpenAI Realtime API** handles low-latency transcription.
    -   **Fine-Tuned BERT** performs Named Entity Recognition (NER) to redact PII (Names, Schools, Locations) *before* the recruiter sees the text.
3.  **Explainable Feedback (XAI):** Our engine analyzes the gap between the candidate's answers and the job description to generate a "Growth Report" post-interview.

---

## System Architecture

EquiHire utilizes a cloud-native hybrid microservices pattern.

### 1. The Gateway (Ballerina)
-   Handles high-concurrency WebSockets from Twilio and Frontend.
-   Manages Identity (Asgardeo) and Authentication.
-   **Orchestrator**: Routes audio to OpenAI and text to the Python Firewall.
-   **Enforcer**: Ensures no unredacted text ever reaches the Recruiter UI.

### 2. The Firewall (Python/FastAPI)
-   Hosts the BERT-NER model.
-   Receives raw text from the Gateway.
-   Redacts sensitive entities (e.g., "[Candidate]", "[University]").
-   Asynchronously computes technical competency scores.

### 3. The Dashboard (React + Vite)
-   Real-time "Blind" Dashboard for recruiters receiving only sanitized text.
-   Candidate portal for microphone access and interview joining.

For a detailed deep-dive into the live voice architecture, see [Voice Architecture](doc/voice-architecture.md).

---

## Tech Stack

| Domain | Technology |
| :--- | :--- |
| **Frontend** | React (Vite), TypeScript, Tailwind CSS |
| **Gateway Service** | **Ballerina** (Swan Lake) |
| **AI Service** | Python 3.10, FastAPI, PyTorch (BERT) |
| **Realtime AI** | OpenAI Realtime API (WebSocket) |
| **Identity** | **WSO2 Asgardeo** (OIDC/OAuth2) |
| **Communication** | Twilio Programmable Voice |
| **Database** | PostgreSQL (Supabase) |

---

## Getting Started

### Prerequisites
*   Ballerina (Swan Lake Update 8+)
*   Python 3.10+
*   Node.js 18+
*   Supabase Account (for Database)
*   OpenAI API Key (for Transcription)

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/YourUsername/EquiHire-Core.git
    cd EquiHire-Core
    ```

2.  **Database Setup (Supabase)**
    Run the SQL scripts in `supabase_schema.sql` via your Supabase SQL Editor.

3.  **Backend Gateway (Ballerina)**
    ```bash
    cd ballerina-gateway
    cp Config.toml.example Config.toml
    # Update Config.toml with your keys
    bal run
    ```

4.  **AI Firewall (Python)**
    ```bash
    cd python-ai-engine
    pip install -r requirements.txt
    uvicorn main:app --port 8000 --reload
    ```

5.  **Frontend (React)**
    ```bash
    cd react-frontend
    npm install
    npm run dev
    ```

---

## Documentation

We have detailed documentation available in the `doc/` folder:

-   **[System Overview](doc/README.md)**: General guide.
-   **[Voice Architecture](doc/voice-architecture.md)**: Explains the "Bias Firewall" and PII redaction flow.
-   **[API Reference](doc/api-endpoints.md)**: List of HTTP and WebSocket endpoints.

---

## Project Structure

```
EquiHire-Core/
├── ballerina-gateway/       # [BACKEND] API Gateway & Orchestrator
│   ├── modules/
│   │   ├── openai/          # OpenAI Realtime Client
│   │   └── ...
│   ├── api.bal              # REST API Service
│   └── service.bal          # WebSocket Services (The Relay)
│
├── python-ai-engine/        # [AI ENGINE] PII Redaction Service
│   └── main.py              # Firewall Endpoint (/sanitize)
│
├── react-frontend/          # [FRONTEND] Recruiter Dashboard
│
├── doc/                     # Documentation
└── README.md
```

---

## License

This project is licensed under the MIT License.
