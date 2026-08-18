# Mentor Backend

Python/FastAPI API service and AI orchestration workers. See [../docs/technical_spec.md](../docs/technical_spec.md) for architecture.

## Run locally

```bash
pip install -e .
uvicorn app.main:app --reload
```

Then check `http://localhost:8000/health`.
