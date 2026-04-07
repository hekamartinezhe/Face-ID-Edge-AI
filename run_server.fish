set -x PYTHONPATH (pwd) $PYTHONPATH

source venv/bin/activate.fish

uvicorn backend_api.main:app --host 0.0.0.0 --port 8000 --reload
