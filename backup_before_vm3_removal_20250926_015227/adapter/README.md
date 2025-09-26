# LLM Adapter for TMF921 Intent Generation

REST service that converts natural language to TMF921-compliant Intent JSON using Claude CLI.

## Features

- TMF921 Intent generation with `targetSite` field (edge1/edge2/both)
- JSON-only output enforcement
- Schema validation
- Simple web UI
- Mock SLO endpoint for testing

## Setup

```bash
pip install -r requirements.txt
```

## Run

```bash
python app/main.py
```

Access UI at `http://localhost:8888`

## API Endpoints

- `POST /generate_intent` - Generate TMF921 intent from natural language
- `GET /mock/slo` - Mock SLO metrics
- `GET /health` - Health check
- `GET /` - Web UI

## Testing

```bash
pytest tests/
```