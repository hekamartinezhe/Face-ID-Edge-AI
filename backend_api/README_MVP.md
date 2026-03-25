MVP Quickstart — Face-ID Edge AI (backend)

Resumen rápido
- Endpoints compatibles con la app Flutter:
  - `GET /status` — status básico
  - `POST /register` — payload `{"nombre": "Juan", "vector": [..512 floats..]}`
  - `POST /asistence` — payload `{"vector": [..512 floats..]}` -> returns best match
  - `POST /recognize_and_attendance` — payload `{"image": "<base64>", "clase_id": "...", "user_id":"..."}` (MVP: encola/guarda imagen para procesamiento offline)

Dependencias mínimas (ejemplo)
```bash
python -m pip install fastapi uvicorn numpy torch opencv-python
# opcional (persistencia Mongo):
python -m pip install motor
```

Ejecutar backend (desde la raíz del repo):
```bash
python backend_api/main.py
# o especificando python absoluto:
# python /path/to/repo/backend_api/main.py
```

Configuración y notas importantes
- El backend guarda embeddings en MongoDB si exportas `MONGO_URI`; si no, guarda en `backend_api/data/embeddings.jsonl`.
- `AdaFaceInference` (en `ai_research/inference.py`) espera checkpoints en rutas relativas en `ai_research/` (p.ej. `ai_research/models/adaface_ir101_ms1mv3.ckpt`) o acepta `model_path` absoluto. Si falta el .ckpt la clase lanza `FileNotFoundError`.
- Para la expo: preferir extracción on-device (la app ya extrae embeddings en `camara_screen.dart`) y usar `/register` y `/asistence` para el flujo de MVP. Esto evita latencia por inferencia server-side.

Pruebas rápidas (curl)
```bash
# status
curl http://127.0.0.1:8000/status

# register
curl -X POST http://127.0.0.1:8000/register -H 'Content-Type: application/json' \
  -d '{"nombre":"TestUser","vector":[0,0,0]}'

# asistence
curl -X POST http://127.0.0.1:8000/asistence -H 'Content-Type: application/json' \
  -d '{"vector":[0,0,0]}'

# recognize_and_attendance (envía base64)
# curl -X POST http://127.0.0.1:8000/recognize_and_attendance -H 'Content-Type: application/json' \
#   -d '{"image":"<base64>","clase_id":"M101","user_id":"u123"}'
```

Siguientes pasos sugeridos antes de exponer
- Si quieres reconocimiento server-side activo: añadir un worker que procese `backend_api/data/` images con `AdaFaceInference` (lo hago si confirmas).
- Verificar `apiUrl` en la app Flutter (usar la IP local de la máquina donde corre el backend o ngrok) y aumentar timeout en llamadas si usar inference server-side.

Contacto
- Cambios principales en `backend_api/main.py` y `ai_research/inference.py`.
