from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class UserSchema(BaseModel):
    name: str
    uid: str
    role: str # 'docente' o 'alumno'
    face_embeddings: Optional[List[float]] = None

class AttendanceSchema(BaseModel):
    user_id: str
    schedule_id: str
    timestamp: datetime = datetime.now()
    status: str # 'Presente', 'Retardo', 'Falta'
    device_ip: str