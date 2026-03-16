from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

app = FastAPI(title="Face-ID Edge AI API")

# Configuración de CORS para permitir la comunicación con Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # En producción, restringir a la IP del S23
    allow_methods=["*"],
    allow_headers=["*"],
)

# Lista blanca de IPs autorizadas (Simulada para la red de la facultad)
ALLOWED_NETWORKS = ["192.168.", "127.0.0.1", "10.0."]

@app.middleware("http")
async def validate_ip_middleware(request: Request, call_next):
    client_ip = request.client.host
    # Permitir solo si la IP está en el rango autorizado
    if not any(client_ip.startswith(net) for net in ALLOWED_NETWORKS):
        # Opcional: Bloquear acceso o marcar como "No Autorizado"
        pass 
    response = await call_next(request)
    return response

@app.get("/status")
async def get_status(request: Request):
    return {
        "status": "online",
        "client_ip": request.client.host,
        "authorized": any(request.client.host.startswith(net) for net in ALLOWED_NETWORKS)
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)