from fastapi import FastAPI, Request, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import numpy as np
import torch
import uvicorn
import os
import base64
import json
from datetime import datetime

# Optional async MongoDB persistence (motor). If MONGO_URI not set, fallback to local file.
MONGO_URI = os.environ.get('MONGO_URI')
use_mongo = False
if MONGO_URI:
    try:
        from motor.motor_asyncio import AsyncIOMotorClient
        mongo_client = AsyncIOMotorClient(MONGO_URI)
        db = mongo_client.get_default_database()
        use_mongo = True
    except Exception:
        use_mongo = False

app = FastAPI(title="Face-ID Edge AI API")

# Inicialización del entorno de IA
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using {device}")

class FaceVector(BaseModel):
    id_alumno: str
    embedding: List[float]

# Lista blanca de IPs autorizadas
ALLOWED_NETWORKS = ["192.168.", "127.0.0.1", "10.0."]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # En producción, restringir a la IP del S23 o clientes específicos
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def validate_ip_middleware(request: Request, call_next):
    client_ip = request.client.host
    # Permitir solo si la IP está en el rango autorizado
    if not any(client_ip.startswith(net) for net in ALLOWED_NETWORKS):
        # Aquí podrías levantar un raise HTTPException(status_code=403, detail="Red no autorizada")
        pass 
    return await call_next(request)

@app.get("/")
def validate_connection():
    return {"Estado": f"Conectado a {device}"}

@app.get("/status")
async def get_status(request: Request):
    return {
        "status": "online",
        "client_ip": request.client.host,
        "authorized": any(request.client.host.startswith(net) for net in ALLOWED_NETWORKS)
    }

@app.post("/registrar")
async def registrar_alumno(data: FaceVector):
    # inserción a DB
    print("tmb jala")
    return {"mensaje": f"Alumno registrado: {data.id_alumno}"}

@app.post("/verificar")
async def verificar_asistencia(data: FaceVector):
    # En el Sprint 2 aquí entrará la comparación
    vector_np = np.array(data.embedding)
    print(data)
    return {
        "identificado": True,
        "alumno": data.id_alumno,
        "dimensiones_recibidas": vector_np.shape[0],
        "Umbral (distancia)": 0.35
    }


# -------------------- MVP endpoints compatible con Flutter --------------------
def _ensure_data_dir():
    d = os.path.join(os.path.dirname(__file__), 'data')
    os.makedirs(d, exist_ok=True)
    return d

async def _save_record(record: dict):
    record['timestamp'] = datetime.utcnow().isoformat()
    if use_mongo:
        await db.embeddings.insert_one(record)
    else:
        d = _ensure_data_dir()
        path = os.path.join(d, 'embeddings.jsonl')
        with open(path, 'a', encoding='utf-8') as f:
            f.write(json.dumps(record, ensure_ascii=False) + '\n')

def _load_all_local():
    d = _ensure_data_dir()
    path = os.path.join(d, 'embeddings.jsonl')
    records = []
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    records.append(json.loads(line))
                except Exception:
                    continue
    return records

def _cosine(a, b):
    a = np.array(a)
    b = np.array(b)
    if a.size == 0 or b.size == 0:
        return 0.0
    na = np.linalg.norm(a)
    nb = np.linalg.norm(b)
    if na == 0 or nb == 0:
        return 0.0
    return float(np.dot(a, b) / (na * nb))


@app.post('/register')
async def register_user(payload: dict):
    # Expected: {'nombre': str, 'vector': [float,...]}
    nombre = payload.get('nombre') or payload.get('id_alumno')
    vector = payload.get('vector') or payload.get('embedding')
    if not nombre or not vector:
        raise HTTPException(status_code=400, detail='nombre and vector required')

    record = {'nombre': nombre, 'vector': vector}
    await _save_record(record)
    return {'message': f'Registered {nombre}'}


@app.post('/asistence')
async def asistence(payload: dict):
    # Expected: {'vector': [float,...]} -> returns best match if any
    vector = payload.get('vector')
    if not vector:
        raise HTTPException(status_code=400, detail='vector required')

    # load stored
    stored = []
    if use_mongo:
        cursor = db.embeddings.find({})
        stored = [doc async for doc in cursor]
    else:
        stored = _load_all_local()

    best = None
    best_score = -1.0
    for rec in stored:
        vec = rec.get('vector')
        if vec:
            score = _cosine(vector, vec)
            if score > best_score:
                best_score = score
                best = rec

    threshold = 0.8
    if best and best_score >= threshold:
        return {'reconocido': True, 'nombre': best.get('nombre'), 'confianza': best_score}
    else:
        return {'reconocido': False, 'mensaje': 'No match', 'confianza': best_score}


@app.post('/recognize_and_attendance')
async def recognize_and_attendance(payload: dict):
    # Expected from app: {'image': base64str, 'clase_id': ..., 'user_id': ...}
    b64 = payload.get('image')
    clase_id = payload.get('clase_id')
    user_id = payload.get('user_id')
    if not b64:
        raise HTTPException(status_code=400, detail='image required')

    # Save image temporarily
    d = _ensure_data_dir()
    imgbytes = base64.b64decode(b64)
    filename = os.path.join(d, f'image_{int(datetime.utcnow().timestamp())}.jpg')
    with open(filename, 'wb') as f:
        f.write(imgbytes)

    # For MVP: we don't run heavy model here. Instead, respond 'not recognized' and store for offline processing.
    await _save_record({'nombre': None, 'vector': None, 'image_path': filename, 'clase_id': clase_id, 'user_id': user_id})
    return {'reconocido': False, 'mensaje': 'Enqueued for processing', 'confianza': 0.0}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)