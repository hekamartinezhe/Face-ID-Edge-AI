from fastapi import FastAPI, Request, HTTPException, UploadFile, Form
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
import motor.motor_asyncio
import anyio
from PIL import Image
import io

# Import AdaFaceInference
from ai_research.inference import AdaFaceInference

# MongoDB setup
MONGO_URI = os.environ.get('MONGO_URI', 'mongodb://localhost:27017/faceid')
mongo_client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
db = mongo_client['faceid']  # Especificar explícitamente el nombre de la base de datos
collection = db.alumnos

app = FastAPI(title="Face-ID Edge AI API")

# Inicialización del entorno de IA
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using {device}")

# Initialize AdaFace
adaface = AdaFaceInference(
    model_path='ai_research/models/adaface_ir101_ms1mv3.ckpt',
    architecture='ir_101',
    device=device
)

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

def _cosine_similarity(a: List[float], b: List[float]) -> float:
    a_np = np.array(a)
    b_np = np.array(b)
    dot = np.dot(a_np, b_np)
    norm_a = np.linalg.norm(a_np)
    norm_b = np.linalg.norm(b_np)
    return dot / (norm_a * norm_b) if norm_a and norm_b else 0.0

async def _generate_embedding(image_bytes: bytes) -> List[float]:
    # Run in thread to avoid blocking
    def sync_generate():
        pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        # Convert to numpy BGR
        np_img = np.array(pil_image)[:, :, ::-1]  # RGB to BGR
        embedding, _ = adaface.run_inference(np_img)
        if embedding is None:
            raise ValueError("No face detected")
        return embedding
    return await anyio.to_thread.run_sync(sync_generate)

@app.post("/registrar")
async def registrar_alumno(
    id_alumno: str = Form(...),
    imagen: UploadFile = UploadFile(...)
):
    try:
        image_bytes = await imagen.read()
        embedding = await _generate_embedding(image_bytes)
        doc = {
            "id_alumno": id_alumno,
            "embedding": embedding,
            "timestamp": datetime.utcnow()
        }
        await collection.insert_one(doc)
        return {"mensaje": f"Alumno registrado: {id_alumno}"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/asistence")
async def verificar_asistencia(imagen: UploadFile = UploadFile(...)):
    try:
        image_bytes = await imagen.read()
        embedding = await _generate_embedding(image_bytes)
        
        # Query all embeddings
        cursor = collection.find({})
        best_match = None
        best_score = -1.0
        async for doc in cursor:
            stored_emb = doc.get("embedding")
            if stored_emb:
                score = _cosine_similarity(embedding, stored_emb)
                if score > best_score:
                    best_score = score
                    best_match = doc
        
        threshold = 0.8  # Adjust as needed
        if best_match and best_score >= threshold:
            return {
                "identificado": True,
                "alumno": best_match["id_alumno"],
                "confianza": best_score
            }
        else:
            return {
                "identificado": False,
                "mensaje": "No match",
                "confianza": best_score
            }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)