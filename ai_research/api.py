import os
import cv2
import torch
import time
import sys
import numpy as np
import warnings
from fastapi import FastAPI, File, UploadFile, Form
import uvicorn
from pyngrok import ngrok

warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*VisibleDeprecationWarning.*")

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from inference import AdaFaceInference
except ImportError as e:
    print(f"Error de importación: {e}")
    sys.exit(1)

app = FastAPI(title="Face-ID Edge AI API")
engine = None
UMBRAL = 0.45

def inicializar_modelo():
    global engine
    MODEL_PATH = 'models/adaface_ir101_ms1mv3.ckpt'
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    
    print("--- INICIANDO SISTEMA FACE-ID API ---")
    if device == 'cuda':
        print(f"Hardware acelerado detectado: {torch.cuda.get_device_name(0)}")
    else:
        print("Advertencia: No se detectó CUDA. Corriendo en CPU.")

    try:
        engine = AdaFaceInference(
            model_path=MODEL_PATH, 
            architecture='ir_101', 
            device=device
        )
        print("AdaFace cargado en memoria correctamente.")
    except Exception as e:
        print(f"Error crítico cargando el modelo: {e}")
        sys.exit(1)

@app.on_event("startup")
async def startup_event():
    inicializar_modelo()

def registrar_asistencia_log(nombre, score):
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[LOG] {timestamp} - Sujeto: {nombre} - Confianza: {score:.4f}")

@app.get("/status")
async def get_status():
    return {
        "status": "online",
        "device": 'cuda' if torch.cuda.is_available() else 'cpu',
        "modelo_cargado": engine is not None
    }

@app.post("/register")
async def register_face(nombre: str = Form(...), file: UploadFile = File(...)):
    if engine is None:
        return {"error": "El motor de inferencia no está listo."}

    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if frame is None:
        return {"error": "La imagen está corrupta o el formato es inválido."}
    
    exito, mensaje = engine.registrar_nuevo_usuario(frame, nombre)
    if not exito:
        return {"error": mensaje}
        
    return {"mensaje": mensaje, "status": "registrado"}

@app.post("/asistancee")
async def check_assistance(file: UploadFile = File(...)):
    if engine is None:
        return {"error": "El motor de inferencia no está listo."}

    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if frame is None:
        return {"error": "No se pudo decodificar la imagen."}

    start_time = time.time()
    try:
        nombre_detectado, score = engine.run_inference(frame) 
        ms = (time.time() - start_time) * 1000

        if score > UMBRAL:
            registrar_asistencia_log(nombre_detectado, score)
            return {
                "resultado": "reconocido",
                "nombre": nombre_detectado,
                "confianza": float(score),
                "tiempo_procesamiento_ms": round(ms, 2)
            }
        else:
            return {
                "resultado": "desconocido",
                "confianza": float(score),
                "tiempo_procesamiento_ms": round(ms, 2)
            }
    except Exception as e:
        return {"error": f"Fallo interno en la inferencia: {str(e)}"}

if __name__ == "__main__":
    print("[DEBUG] Paso 1: Entrando al bloque de ejecución principal...")
    puerto = 8000
    
    try:
        print("[DEBUG] Paso 2: Intentando conectar ngrok...")
        ngrok.set_auth_token("2yIcqNUGU5aXGaMGAveQPbqmTHx_25j6ckQ8iwC93bppgW9u2")
        public_url = ngrok.connect(puerto).public_url
        print(f"TÚNEL NGROK ACTIVO: {public_url}")
        print(f"Prueba la API en: {public_url}/docs")
    except Exception as e:
        print(f"Error al iniciar ngrok: {e}")

    print("[DEBUG] Paso 3: Levantando Uvicorn...")
    uvicorn.run("api:app", host="0.0.0.0", port=puerto, log_level="info")
