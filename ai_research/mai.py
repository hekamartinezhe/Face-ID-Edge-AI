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
import motor.motor_asyncio
import anyio
from PIL import Image
import io

warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*VisibleDeprecationWarning.*")

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from inference import AdaFaceInference
except ImportError as e:
    print(f"Error de importación: {e}")
    sys.exit(1)

# MongoDB setup
MONGO_URI = os.environ.get('MONGO_URI', 'mongodb+srv://hekamartinezhe_db_user:YRatrvJpqbFuwO0J@cluster0.qdqta8i.mongodb.net/?appName=Cluster0')
mongo_client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URI)
db = mongo_client['faceid']  # Especificar explícitamente el nombre de la base de datos
collection = db.alumnos

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

def _cosine_similarity(a: list, b: list) -> float:
    a_np = np.array(a)
    b_np = np.array(b)
    dot = np.dot(a_np, b_np)
    norm_a = np.linalg.norm(a_np)
    norm_b = np.linalg.norm(b_np)
    return dot / (norm_a * norm_b) if norm_a and norm_b else 0.0

async def _generate_embedding(image_bytes: bytes) -> list:
    # Run in thread to avoid blocking
    def sync_generate():
        try:
            pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
            # Validar que la imagen tenga tamaño razonable
            if pil_image.size[0] < 50 or pil_image.size[1] < 50:
                raise ValueError("Image too small")
            # Convert to numpy BGR
            np_img = np.array(pil_image)[:, :, ::-1]  # RGB to BGR
            embedding, score = engine.run_inference(np_img)
            if embedding is None:
                raise ValueError("No face detected in image")
            return embedding
        except ValueError as e:
            raise e
        except Exception as e:
            raise ValueError(f"Face detection error: {str(e)}")
    return await anyio.to_thread.run_sync(sync_generate)

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

    try:
        contents = await file.read()
        if len(contents) == 0:
            return {"error": "Image file is empty", "status": "error"}
        embedding = await _generate_embedding(contents)
        doc = {
            "id_alumno": nombre,
            "embedding": embedding,
            "timestamp": time.time()
        }
        await collection.insert_one(doc)
        return {"mensaje": f"Alumno registrado: {nombre}", "status": "registrado"}
    except ValueError as e:
        return {"error": str(e), "status": "error"}
    except Exception as e:
        print(f"[ERROR] /register: {e}")
        return {"error": f"Internal error: {str(e)}", "status": "error"}

@app.post("/asistence")
async def check_assistance(file: UploadFile = File(...)):
    if engine is None:
        return {"error": "El motor de inferencia no está listo."}

    try:
        contents = await file.read()
        if len(contents) == 0:
            return {
                "resultado": "desconocido",
                "confianza": 0.0,
                "error": "Image file is empty",
                "tiempo_procesamiento_ms": 0.0
            }
        
        start_time = time.time()
        embedding = await _generate_embedding(contents)
        
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
        
        ms = (time.time() - start_time) * 1000
        
        if best_match and best_score >= UMBRAL:
            nombre_detectado = best_match["id_alumno"]
            registrar_asistencia_log(nombre_detectado, best_score)
            return {
                "resultado": "reconocido",
                "nombre": nombre_detectado,
                "confianza": float(best_score),
                "tiempo_procesamiento_ms": round(ms, 2)
            }
        else:
            return {
                "resultado": "desconocido",
                "confianza": float(best_score),
                "tiempo_procesamiento_ms": round(ms, 2)
            }
    except ValueError as e:
        print(f"[WARNING] /asistence: {e}")
        return {
            "resultado": "desconocido",
            "confianza": 0.0,
            "error": str(e),
            "tiempo_procesamiento_ms": 0.0
        }
    except Exception as e:
        print(f"[ERROR] /asistence: {e}")
        import traceback
        traceback.print_exc()
        return {
            "resultado": "desconocido",
            "confianza": 0.0,
            "error": f"Internal error: {str(e)}",
            "tiempo_procesamiento_ms": 0.0
        }

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
    uvicorn.run(app, host="0.0.0.0", port=puerto, log_level="info")
