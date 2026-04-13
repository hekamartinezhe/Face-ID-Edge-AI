import base64
import io
import json
import os
import sys
import time
import uuid
from datetime import datetime, timedelta

import anyio
import numpy as np
import torch
import uvicorn
import warnings
from fastapi import FastAPI, File, HTTPException, UploadFile, Form, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
from pyngrok import ngrok
from typing import Any, Dict, List, Optional


warnings.filterwarnings("ignore", category=DeprecationWarning)
warnings.filterwarnings("ignore", message=".*VisibleDeprecationWarning.*")

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from inference import AdaFaceInference
except ImportError as e:
    print(f"Error de importación: {e}")
    sys.exit(1)

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "face_db.json")
DB_LOCK = anyio.Lock()

app = FastAPI(title="Face-ID Edge AI API")
engine = None
UMBRAL = 0.45

class RecognizeRequest(BaseModel):
    vector: List[float]
    timestamp: Optional[int] = None
    device_id: Optional[str] = None


def _ensure_db_file() -> None:
    if not os.path.exists(DB_PATH):
        with open(DB_PATH, "w", encoding="utf-8") as f:
            json.dump({"users": [], "schedules": [], "attendances": []}, f, ensure_ascii=False, indent=2)


def _normalize_db(data: Any) -> Dict[str, Any]:
    if isinstance(data, list):
        return {"users": data, "schedules": [], "attendances": []}
    if not isinstance(data, dict):
        return {"users": [], "schedules": [], "attendances": []}

    return {
        "users": data.get("users") if isinstance(data.get("users"), list) else [],
        "schedules": data.get("schedules") if isinstance(data.get("schedules"), list) else [],
        "attendances": data.get("attendances") if isinstance(data.get("attendances"), list) else []
    }


def _get_entry_id(entry: Dict[str, Any]) -> Optional[str]:
    return (entry.get("id") or entry.get("id_alumno") or entry.get("alumno_id")
            or entry.get("docente_id") or entry.get("name") or entry.get("email"))


async def _load_db() -> Dict[str, Any]:
    def sync_load() -> Dict[str, Any]:
        _ensure_db_file()
        with open(DB_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            return _normalize_db(data)
    return await anyio.to_thread.run_sync(sync_load)


async def _save_db(db_data: Dict[str, Any]) -> None:
    def sync_save() -> None:
        temp_path = DB_PATH + ".tmp"
        with open(temp_path, "w", encoding="utf-8") as f:
            json.dump(db_data, f, ensure_ascii=False, indent=2)
        os.replace(temp_path, DB_PATH)
    await anyio.to_thread.run_sync(sync_save)


async def _append_or_update_user(user: Dict[str, Any]) -> None:
    async with DB_LOCK:
        db_data = await _load_db()
        user_id = _get_entry_id(user)
        if not user_id:
            raise ValueError("User ID missing")

        existing = next((item for item in db_data["users"] if _get_entry_id(item) == user_id), None)
        if existing:
            existing.update(user)
        else:
            db_data["users"].append(user)
        await _save_db(db_data)


async def _append_schedule(schedule: Dict[str, Any]) -> None:
    async with DB_LOCK:
        db_data = await _load_db()
        class_id = schedule.get("clase_id") or str(uuid.uuid4())
        schedule["clase_id"] = class_id
        existing = next((item for item in db_data["schedules"] if item.get("clase_id") == class_id), None)
        if existing:
            existing.update(schedule)
        else:
            db_data["schedules"].append(schedule)
        await _save_db(db_data)


async def _append_attendance(attendance: Dict[str, Any]) -> None:
    async with DB_LOCK:
        db_data = await _load_db()
        attendance["attendance_id"] = attendance.get("attendance_id") or str(uuid.uuid4())
        db_data["attendances"].append(attendance)
        await _save_db(db_data)


async def _find_best_match(embedding: List[float]) -> (Optional[Dict[str, Any]], float):
    db_data = await _load_db()
    best_match = None
    best_score = -1.0
    for item in db_data["users"]:
        stored = item.get("embedding")
        if isinstance(stored, list) and len(stored) == len(embedding):
            score = _cosine_similarity(embedding, stored)
            if score > best_score:
                best_score = score
                best_match = item
    return best_match, float(best_score)


async def _find_user(user_id: str) -> Optional[Dict[str, Any]]:
    db_data = await _load_db()
    return next((item for item in db_data["users"] if _get_entry_id(item) == user_id), None)


async def _find_class(clase_id: str) -> Optional[Dict[str, Any]]:
    db_data = await _load_db()
    return next((item for item in db_data["schedules"] if item.get("clase_id") == clase_id), None)


async def _list_users(role: Optional[str] = None, search: Optional[str] = None, grupo: Optional[str] = None) -> List[Dict[str, Any]]:
    db_data = await _load_db()
    users = [user for user in db_data["users"] if role is None or str(user.get("role")).lower() == role.lower()]
    if search:
        users = [user for user in users if search.lower() in str(user.get("name", "")).lower() or search.lower() in str(user.get("email", "")).lower()]
    if grupo:
        users = [user for user in users if str(user.get("grupo", "")).lower() == grupo.lower()]
    return users


def _filter_user_output(user: Dict[str, Any]) -> Dict[str, Any]:
    return {k: v for k, v in user.items() if k not in {"embedding", "password"}}


async def _find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    db_data = await _load_db()
    return next((item for item in db_data["users"] if str(item.get("email")).lower() == email.lower()), None)


async def _find_user_by_token(token: str) -> Optional[Dict[str, Any]]:
    db_data = await _load_db()
    return next((item for item in db_data["users"] if str(item.get("token")) == token), None)


async def _set_user_token(user_id: str, token: str) -> None:
    async with DB_LOCK:
        db_data = await _load_db()
        for item in db_data["users"]:
            if _get_entry_id(item) == user_id:
                item["token"] = token
                break
        await _save_db(db_data)


def _parse_time_str(time_string: Optional[str]) -> Optional[datetime]:
    if not time_string:
        return None
    try:
        return datetime.strptime(time_string, "%H:%M")
    except ValueError:
        return None


async def _get_horario(alumno_id: str) -> List[Dict[str, Any]]:
    db_data = await _load_db()
    return [item for item in db_data["schedules"] if item.get("owner_role") == "alumno" and item.get("owner_id") == alumno_id]


async def _get_asistencias_alumno(alumno_id: str) -> List[Dict[str, Any]]:
    db_data = await _load_db()
    return [item for item in db_data["attendances"] if item.get("alumno_id") == alumno_id]


async def _get_clases_docente(docente_id: Optional[str] = None) -> List[Dict[str, Any]]:
    db_data = await _load_db()
    clases = [item for item in db_data["schedules"] if item.get("owner_role") == "docente"]
    if docente_id:
        clases = [item for item in clases if item.get("owner_id") == docente_id]
    return clases


async def _get_asistencias_docente(docente_id: Optional[str] = None, clase_id: Optional[str] = None, fecha: Optional[str] = None) -> List[Dict[str, Any]]:
    db_data = await _load_db()
    asistencias = db_data["attendances"]
    if clase_id:
        asistencias = [item for item in asistencias if item.get("clase_id") == clase_id]
    if docente_id:
        clases = await _get_clases_docente(docente_id)
        clase_ids = {item.get("clase_id") for item in clases}
        asistencias = [item for item in asistencias if item.get("clase_id") in clase_ids]
    if fecha:
        asistencias = [item for item in asistencias if item.get("fecha") == fecha]
    return asistencias


def _evaluate_attendance_status(schedule: Dict[str, Any]) -> str:
    inicio = _parse_time_str(schedule.get("inicio"))
    fin = _parse_time_str(schedule.get("fin"))
    if inicio is None or fin is None:
        return "Sin horario"

    now = datetime.now()
    inicio_dt = now.replace(hour=inicio.hour, minute=inicio.minute, second=0, microsecond=0)
    fin_dt = now.replace(hour=fin.hour, minute=fin.minute, second=0, microsecond=0)
    tolerancia = int(schedule.get("tolerancia_min", 0))
    inicio_minus_tol = inicio_dt - timedelta(minutes=tolerancia)
    fin_plus_tol = fin_dt + timedelta(minutes=tolerancia)

    if now < inicio_minus_tol:
        return "Antes de iniciar"
    if now > fin_plus_tol:
        return "Falta"
    if now <= inicio_dt + timedelta(minutes=tolerancia):
        return "Presente"
    return "Retardo"


@app.on_event("startup")
async def startup_event():
    _ensure_db_file()
    inicializar_modelo()

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
            result = engine.run_inference(np_img)
            if result is None:
                raise ValueError("No face detected in image")

            if isinstance(result, (list, tuple)):
                if len(result) >= 2:
                    embedding = result[0]
                    score = result[1]
                else:
                    embedding = result[0]
                    score = None
            else:
                embedding = result
                score = None

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

@app.post("/recognize")
async def recognize_vector(payload: RecognizeRequest):
    if engine is None:
        raise HTTPException(status_code=503, detail="El motor de inferencia no está listo.")

    if not payload.vector:
        raise HTTPException(status_code=400, detail="El campo 'vector' es obligatorio.")

    best_match, best_score = await _find_best_match(payload.vector)
    matched = best_match is not None and best_score >= UMBRAL

    return {
        "status": "ok",
        "match": matched,
        "label": _get_entry_id(best_match) if matched and best_match else None,
        "confidence": float(best_score),
        "assistance": False,
        "message": "reconocido" if matched else "desconocido"
    }


@app.post("/admin/alumnos")
async def admin_register_alumno(request: Request):
    payload = await request.json()
    name = payload.get("name")
    email = payload.get("email")
    matricula = payload.get("matricula")
    password = payload.get("password")
    if not name or not email or not matricula or not password:
        raise HTTPException(status_code=400, detail="Faltan campos obligatorios para registrar alumno.")

    embedding = None
    face_image_base64 = payload.get("face_image")
    if face_image_base64:
        try:
            image_bytes = base64.b64decode(face_image_base64)
            embedding = await _generate_embedding(image_bytes)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Error procesando la imagen de alumno: {e}")

    user = {
        "id": payload.get("id") or str(uuid.uuid4()),
        "role": "alumno",
        "name": name,
        "email": email,
        "matricula": matricula,
        "password": password,
        "grupo": payload.get("grupo"),
        "carrera": payload.get("carrera"),
        "timestamp": time.time(),
    }
    if embedding is not None:
        user["embedding"] = embedding
    await _append_or_update_user(user)
    return JSONResponse(status_code=201, content=_filter_user_output(user))


@app.post("/admin/docentes")
async def admin_register_docente(request: Request):
    payload = await request.json()
    name = payload.get("name")
    email = payload.get("email")
    password = payload.get("password")
    if not name or not email or not password:
        raise HTTPException(status_code=400, detail="Faltan campos obligatorios para registrar docente.")

    user = {
        "id": payload.get("id") or str(uuid.uuid4()),
        "role": "docente",
        "name": name,
        "email": email,
        "password": password,
        "especialidad": payload.get("especialidad"),
        "timestamp": time.time(),
    }
    await _append_or_update_user(user)
    return JSONResponse(status_code=201, content=_filter_user_output(user))


@app.post("/auth/login")
async def auth_login(request: Request):
    payload = await request.json()
    email = payload.get("email")
    password = payload.get("password")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Email y contraseña son obligatorios.")

    user = await _find_user_by_email(email)
    if not user or user.get("password") != password:
        raise HTTPException(status_code=401, detail="Credenciales inválidas.")

    token = str(uuid.uuid4())
    await _set_user_token(_get_entry_id(user), token)
    user["token"] = token

    return {
        "token": token,
        "user": _filter_user_output(user),
    }


@app.post("/auth/login-face")
async def auth_login_face(request: Request):
    payload = await request.json()
    face_image_base64 = payload.get("image")

    if not face_image_base64:
        raise HTTPException(status_code=400, detail="La imagen facial es obligatoria.")

    try:
        image_bytes = base64.b64decode(face_image_base64)
        embedding = await _generate_embedding(image_bytes)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error procesando la imagen facial: {e}")

    best_match, best_score = await _find_best_match(embedding)
    if not best_match or best_score < UMBRAL:
        raise HTTPException(status_code=404, detail="Rostro no reconocido.")

    token = str(uuid.uuid4())
    await _set_user_token(_get_entry_id(best_match), token)
    best_match["token"] = token

    return {
        "token": token,
        "user": _filter_user_output(best_match),
    }


@app.get("/auth/me")
async def auth_me(request: Request):
    auth_header = request.headers.get("authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token de autenticación ausente.")

    token = auth_header.split(" ", 1)[1]
    user = await _find_user_by_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Token inválido.")

    return _filter_user_output(user)


@app.get("/admin/alumnos")
async def list_alumnos(search: Optional[str] = None, grupo: Optional[str] = None):
    users = await _list_users(role="alumno", search=search, grupo=grupo)
    return [_filter_user_output(user) for user in users]


@app.get("/admin/docentes")
async def list_docentes():
    users = await _list_users(role="docente")
    return [_filter_user_output(user) for user in users]


@app.post("/horarios")
async def create_schedule(request: Request):
    payload = await request.json()
    owner_id = payload.get("owner_id")
    owner_role = payload.get("owner_role")
    materia = payload.get("materia")
    inicio = payload.get("inicio")
    fin = payload.get("fin")
    if not owner_id or not owner_role or not materia or not inicio or not fin:
        raise HTTPException(status_code=400, detail="Faltan campos obligatorios para crear horario.")

    if _parse_time_str(inicio) is None or _parse_time_str(fin) is None:
        raise HTTPException(status_code=400, detail="Formato de hora inválido. Use HH:MM.")

    schedule = {
        "clase_id": payload.get("clase_id") or str(uuid.uuid4()),
        "owner_id": owner_id,
        "owner_role": owner_role,
        "materia": materia,
        "inicio": inicio,
        "fin": fin,
        "tolerancia_min": int(payload.get("tolerancia_min", 0)),
        "dia": payload.get("dia"),
        "aula": payload.get("aula"),
        "grupo": payload.get("grupo"),
        "timestamp": time.time(),
    }
    await _append_schedule(schedule)
    return JSONResponse(status_code=201, content=schedule)


@app.get("/horarios")
async def list_horarios(owner_id: Optional[str] = None, owner_role: Optional[str] = None):
    db_data = await _load_db()
    schedules = db_data["schedules"]
    if owner_id:
        schedules = [item for item in schedules if item.get("owner_id") == owner_id]
    if owner_role:
        schedules = [item for item in schedules if item.get("owner_role") == owner_role]
    return schedules


@app.get("/alumnos/{alumno_id}/horario")
async def get_alumno_horario(alumno_id: str):
    return await _get_horario(alumno_id)


@app.get("/alumnos/{alumno_id}/asistencias")
async def get_alumno_asistencias(alumno_id: str):
    return await _get_asistencias_alumno(alumno_id)


@app.get("/docente/clases")
async def get_docente_clases(docente_id: Optional[str] = None):
    return await _get_clases_docente(docente_id)


@app.get("/docente/asistencias")
async def get_docente_asistencias(docente_id: Optional[str] = None, clase_id: Optional[str] = None, fecha: Optional[str] = None):
    return await _get_asistencias_docente(docente_id=docente_id, clase_id=clase_id, fecha=fecha)


@app.post("/asistencias")
async def register_attendance(request: Request):
    payload = await request.json()
    alumno_id = payload.get("alumno_id")
    clase_id = payload.get("clase_id")
    face_image_base64 = payload.get("face_image")

    if not alumno_id or not clase_id or not face_image_base64:
        raise HTTPException(status_code=400, detail="Faltan campos obligatorios para registrar asistencia.")

    user = await _find_user(alumno_id)
    if not user or str(user.get("role")).lower() != "alumno":
        raise HTTPException(status_code=404, detail="Alumno no encontrado.")

    schedule = await _find_class(clase_id)
    if not schedule:
        raise HTTPException(status_code=404, detail="Clase no encontrada.")

    try:
        image_bytes = base64.b64decode(face_image_base64)
        embedding = await _generate_embedding(image_bytes)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error procesando la imagen de asistencia: {e}")

    best_match, best_score = await _find_best_match(embedding)
    if not best_match or _get_entry_id(best_match) != alumno_id or best_score < UMBRAL:
        raise HTTPException(status_code=400, detail="No coincide el alumno con la imagen.")

    status = _evaluate_attendance_status(schedule)
    attendance_entry = {
        "alumno_id": alumno_id,
        "clase_id": clase_id,
        "status": status,
        "confidence": float(best_score),
        "timestamp": datetime.now().isoformat(),
        "fecha": datetime.now().strftime("%Y-%m-%d"),
    }
    await _append_attendance(attendance_entry)
    registrar_asistencia_log(alumno_id, best_score)

    return {
        "mensaje": "Asistencia registrada",
        "alumno_id": alumno_id,
        "clase_id": clase_id,
        "status": status,
        "confidence": float(best_score),
    }


@app.post("/register")
async def register_face(nombre: str = Form(...), file: UploadFile = File(...)):
    if engine is None:
        return {"error": "El motor de inferencia no está listo.", "status": "error"}

    try:
        contents = await file.read()
        if len(contents) == 0:
            return {"error": "Image file is empty", "status": "error"}

        embedding = await _generate_embedding(contents)
        entry = {
            "id": nombre,
            "id_alumno": nombre,
            "role": "alumno",
            "embedding": embedding,
            "timestamp": time.time()
        }
        await _append_or_update_user(entry)

        return {"mensaje": f"Alumno registrado: {nombre}", "status": "registrado"}
    except ValueError as e:
        return {"error": str(e), "status": "error"}
    except Exception as e:
        print(f"[ERROR] /register: {e}")
        return {"error": f"Internal error: {str(e)}", "status": "error"}


@app.post("/asistence")
async def check_assistance(file: UploadFile = File(...)):
    if engine is None:
        return {"error": "El motor de inferencia no está listo.", "resultado": "desconocido", "confianza": 0.0, "tiempo_procesamiento_ms": 0.0}

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
        best_match, best_score = await _find_best_match(embedding)
        ms = (time.time() - start_time) * 1000

        if best_match and best_score >= UMBRAL:
            nombre_detectado = _get_entry_id(best_match)
            registrar_asistencia_log(nombre_detectado, best_score)
            return {
                "resultado": "reconocido",
                "nombre": nombre_detectado,
                "confianza": float(best_score),
                "tiempo_procesamiento_ms": round(ms, 2)
            }

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
