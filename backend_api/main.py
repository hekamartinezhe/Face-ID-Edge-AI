from fastapi import FastAPI, Request, HTTPException, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import numpy as np
import torch
import uvicorn
import os
import sys
import base64
import json
from datetime import datetime
import motor.motor_asyncio
import anyio
from PIL import Image
import io

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

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
ckpt_env = os.environ.get('ADAFACE_CKPT')
ckpt_default = os.path.join(ROOT_DIR, 'ai_research', 'models', 'adaface_ir101_ms1mv3.ckpt')
ckpt_path = ckpt_env or ckpt_default
adaface = AdaFaceInference(
    model_path=ckpt_path,
    architecture='ir_101',
    device=device
)

class FaceVector(BaseModel):
    id_alumno: str
    embedding: List[float]

# Lista blanca de IPs autorizadas
ALLOWED_NETWORKS = ["192.168.", "127.0.0.1", "10.0.", "100."]

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
    """
    Calcula similitud coseno entre dos embeddings (ya normalizados).
    Para máxima precisión, los embeddings deben estar L2-normalizados.
    """
    a_np = np.array(a)
    b_np = np.array(b)
    
    # Si los embeddings ya están L2-normalizados, el dot product es suficiente
    # pero recalculamos por si acaso
    dot = np.dot(a_np, b_np)
    norm_a = np.linalg.norm(a_np)
    norm_b = np.linalg.norm(b_np)
    
    if norm_a > 0 and norm_b > 0:
        return float(dot / (norm_a * norm_b))
    return 0.0

async def _generate_embedding(image_bytes: bytes) -> tuple[List[float], float, float]:
    """
    Genera embedding a partir de bytes de imagen.
    Retorna: (embedding_normalizado, norm_score, alignment_quality)
    """
    def sync_generate():
        pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        # Convertir a numpy BGR (como lo espera el modelo)
        np_img = np.array(pil_image)[:, :, ::-1]  # RGB to BGR
        
        # run_inference ahora retorna (embedding, norm_score, alignment_quality)
        embedding, norm_score, alignment_quality = adaface.run_inference(np_img)
        
        if embedding is None:
            raise ValueError("No face detected or alignment failed")
        
        return embedding, norm_score, alignment_quality
    
    return await anyio.to_thread.run_sync(sync_generate)

@app.post("/registrar")
async def registrar_alumno(
    id_alumno: str = Form(...),
    imagen: UploadFile = UploadFile(...)
):
    """
    Registra un alumno con su embedding facial.
    Valida calidad del rostro antes de guardar.
    """
    try:
        image_bytes = await imagen.read()
        embedding, norm_score, alignment_quality = await _generate_embedding(image_bytes)
        
        # Validar calidad mínima
        min_alignment_quality = 0.5
        if alignment_quality < min_alignment_quality:
            raise HTTPException(
                status_code=400, 
                detail=f"Calidad de imagen insuficiente ({alignment_quality:.2f}). "
                       f"Asegúrate de tener buena iluminación y que el rostro esté centrado."
            )
        
        doc = {
            "id_alumno": id_alumno,
            "embedding": embedding,
            "norm_score": norm_score,
            "alignment_quality": alignment_quality,
            "timestamp": datetime.utcnow()
        }
        await collection.insert_one(doc)
        
        return {
            "mensaje": f"Alumno registrado: {id_alumno}",
            "quality_metrics": {
                "alignment_quality": round(alignment_quality, 2),
                "norm_score": round(norm_score, 2)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)