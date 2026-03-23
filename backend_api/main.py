from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
import numpy as np
import torch
import uvicorn

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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)