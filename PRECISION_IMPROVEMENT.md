# 🎯 Guía de Mejora de Precisión - Pre-procesamiento Optimizado

## ¿Qué Cambió?

Se han implementado **3 mejoras principales** en el pre-procesamiento:

### 1️⃣ **Face Alignment Mejorado** (`ai_research/face_alignment/align.py`)

**Antes:**
- MTCNN fijo en GPU (fallaba si no había CUDA)
- No validaba calidad del rostro detectado
- Retornaba solo la imagen alineada

**Después:**
- ✅ Fallback automático a CPU si no hay GPU
- ✅ Validación de calidad (brightness, tamaño)
- ✅ Retorna `(face_pil, quality_score, bbox)`
- ✅ Filtra rostros muy oscuros/claros o muy pequeños

**Cómo funciona:**
```python
face, quality, bbox = align.get_aligned_face(image_path)
if quality < 0.5:
    print(f"Rostro de baja calidad: {quality:.2f}")
```

---

### 2️⃣ **Normalización de Embeddings** (`ai_research/inference.py`)

**Antes:**
- Embeddings SIN normalización L2
- Similitud coseno calculada sobre vectors no normalizados
- No retornaba métricas de calidad

**Después:**
- ✅ L2 Normalization automática
- ✅ Retorna 3 valores: `(embedding, norm_score, alignment_quality)`
- ✅ Mayor estabilidad en similitud coseno
- ✅ Métricas para debugging

**Cómo funciona:**
```python
def normalize_embedding(embedding):
    "Normaliza con L2 norm: ||v|| = 1"
    emb = np.array(embedding)
    return (emb / np.linalg.norm(emb)).tolist()
```

---

### 3️⃣ **Threshold Adaptativo Dinámico** (`backend_api/main.py`)

**Antes:**
- Threshold fijo: 0.8 (igual para todos)
- No consideraba calidad de la imagen actual
- Sin estadísticas de debug

**Después:**
- ✅ Threshold adaptativo basado en `alignment_quality`
- ✅ Mejor calidad de imagen → threshold más bajo (menos restrictivo)
- ✅ Mala calidad → threshold más alto (más restrictivo)
- ✅ Retorna estadísticas completas para debugging

**Fórmula:**
```
base_threshold = 0.80
quality_adjustment = (alignment_quality - 0.5) * 0.2
dynamic_threshold = max(0.70, base_threshold - quality_adjustment)

Ejemplo:
- Si alignment_quality = 0.3 → threshold = 0.80 (muy restrictivo)
- Si alignment_quality = 0.8 → threshold = 0.74 (más permisivo)
```

---

## 📊 Nuevos Endpoints

### `POST /registrar` (Mejorado)
Ahora valida calidad ANTES de guardar:

```bash
curl -X POST http://localhost:8000/registrar \
  -F "id_alumno=A001" \
  -F "imagen=@photo.jpg"
```

**Respuesta:**
```json
{
  "mensaje": "Alumno registrado: A001",
  "quality_metrics": {
    "alignment_quality": 0.85,
    "norm_score": 0.92
  }
}
```

**Si falla por baja calidad:**
```json
{
  "detail": "Calidad de imagen insuficiente (0.25). Asegúrate de tener buena iluminación y que el rostro esté centrado."
}
```

---

### `POST /asistence` (Mejorado)

```bash
curl -X POST http://localhost:8000/asistence \
  -F "imagen=@selfie.jpg"
```

**Respuesta exitosa:**
```json
{
  "identificado": true,
  "alumno": "A001",
  "confianza": 0.925,
  "quality": 0.88,
  "threshold_usado": 0.742
}
```

**Respuesta fallida (con estadísticas):**
```json
{
  "identificado": false,
  "mensaje": "No se encontró coincidencia (mejor puntaje: 0.65)",
  "confianza": 0.65,
  "quality": 0.72,
  "threshold_usado": 0.75,
  "stats": {
    "avg_score": 0.42,
    "std_score": 0.18,
    "total_registros": 5
  }
}
```

---

## 🔧 Cómo Usar las Herramientas de Diagnóstico

### **Opción 1: Script Automático (Recomendado)**

```bash
cd backend_api
python diagnose.py
```

**Qué hace:**
1. ✅ Conecta a tu MongoDB
2. ✅ Carga todos los embeddings registrados
3. ✅ Calcula similitud intra-persona (mismo alumno)
4. ✅ Calcula similitud inter-persona (alumnos diferentes)
5. ✅ Genera reporta con:
   - Estadísticas de similitudes
   - Índice de separación (d-prime)
   - Threshold óptimo recomendado
   - Sugerencias de mejora

**Requisitos:**
- MongoDB corriendo: `mongod`
- Al menos 2 alumnos registrados
- Model cargado (`ai_research/models/adaface_ir101_ms1mv3.ckpt`)

**Salida esperada:**
```
====================================================================
🔍 DIAGNÓSTICO DE PRECISIÓN - Face-ID Edge AI
====================================================================

[1] Conectando a MongoDB...
✅ Base de datos conectada - 5 alumnos registrados

[2] Inicializando modelo AdaFace...
✅ Modelo cargado (device: cuda)

[3] Cargando embeddings de la base de datos...
✅ 5 embeddings cargados

[4] Calculando matriz de similitudes...
   - Analizando matches (mismo alumno)...
     ✓ 5 comparaciones intra-persona generadas
   - Analizando non-matches (diferente alumno)...
     ✓ 10 comparaciones inter-persona

📊 ESTADÍSTICAS DE SIMILITUD
====================================================================

🟢 MATCHES (Mismo alumno):
   Muestras: 5
   Media:    0.935
   Std Dev:  0.025
   ...

🔴 NON-MATCHES (Diferente alumno):
   Muestras: 10
   Media:    0.415
   Std Dev:  0.150
   ...

🎯 ANÁLISIS DE SEPARACIÓN
====================================================================

Índice d-prime: 3.521
Evaluation:     EXCELENTE - Separación muy clara
Error Rate:     0.018

💡 Sugerencias:
   ✅ Rendimiento bueno. La precisión del modelo es aceptable

⚙️ THRESHOLD ÓPTIMO
====================================================================

🎯 Threshold recomendado: 0.82
   F1 Score:  0.973
   Usa threshold = 0.82 para máxima precisión (F1=0.973)
```

---

### **Opción 2: Módulo Python Programático**

```python
from backend_api.eval import PrecisionEvaluator
import numpy as np

evaluator = PrecisionEvaluator()

# Agregar scores reales de tu modelo
for score in intra_persona_scores:
    evaluator.add_match_score(score)

for score in inter_persona_scores:
    evaluator.add_non_match_score(score)

# Obtener recomendaciones
stats = evaluator.get_statistics()
optimal = evaluator.find_optimal_threshold()
quality = evaluator.detect_separation_quality()

print(f"Threshold óptimo: {optimal['optimal_threshold']}")
print(f"F1 Score: {optimal['best_f1_score']}")
print(f"d-prime: {quality['d_prime']}")
```

---

## 📈 Interpretando Resultados

### **d-prime (Índice de Separación)**

| d-prime | Calidad | Acción |
|---------|---------|--------|
| < 1.0 | POBRE | ❌ Muchos falsos positivos/negativos. Mejora modelo |
| 1.0-2.0 | ACEPTABLE | ⚠️ Funcionable pero con errores. Considera mejoras |
| 2.0-3.0 | BUENO | ✅ Buena separación. Funciona bien |
| > 3.0 | EXCELENTE | 🏆 Separación perfecta. Modelo confiable |

### **Métricas de Confusión**

```
True Positive (TP):  Reconoce mismo alumno ✅
False Positive (FP): Reconoce como otro alumno ❌
False Negative (FN): No reconoce mismo alumno ❌
True Negative (TN):  Rechaza diferente alumno ✅

Mejor en lo posible:
- TPR (Recall) alto = Menos falsos negativos
- Precision alta = Menos falsos positivos
- F1 balanceado entre ambos
```

---

## 🚀 Pasos para Mejora Continua

### **Si d-prime < 2.0 (Baja separación)**

1. **Registra más fotos por alumno:**
   ```bash
   # Toma 5-10 fotos de cada alumno en:
   # - Diferentes ángulos (frente, 45°, perfil)
   # - Diferentes iluminaciones (interior, exterior, luz tenue)
   # - Diferentes distancias de la cámara
   ```

2. **Valida calidad de imágenes:**
   - Todos los `alignment_quality` deben ser > 0.6
   - Evita imágenes muy oscuras o muy claras
   - Rostro debe ser >= 50x50 pixels

3. **Ajusta threshold según recomendaciones:**
   - Usa el `optimal_threshold` del diagnóstico
   - Actualiza `backend_api/main.py` línea ~140 si es necesario

4. **Considera fine-tuning:**
   - Si tienes 500+ imágenes por alumno
   - Ejecuta entrenamiento adaptativo con datos locales
   - Consulta `ai_research/train_val.py`

---

## 🐛 Debugging

### **API devuelve HTTP 400 "No face detected"**
- ✅ Solución: Mejor iluminación, acercarse más a la cámara
- ✅ Intent: Rostro muy pequeño o mal alineado

### **Threshold usage muy bajo (0.70) en /asistence**
- ✅ Significa: Image quality baja en la foto actual
- ✅ Usuario debe mejorar condiciones de captura

### **Muchos falsos positivos (reconoce a personas equivocadas)**
- ✅ Opción 1: Aumenta threshold en `/asistence`
- ✅ Opción 2: Agrega más imágenes de entrenamiento
- ✅ Opción 3: Mejora alineación (verifica `align.py`)

### **Muchos falsos negativos (no reconoce personas correctas)**
- ✅ Opción 1: Reduce threshold ligeramente
- ✅ Opción 2: Verifica que la persona esté registrada
- ✅ Opción 3: Registra más variaciones de la misma persona

---

## 📝 Checklist de Optimización

```
Fase 1: Diagnóstico
  [ ] Ejecuta: python diagnose.py
  [ ] Revisa: d-prime score
  [ ] Nota: optimal_threshold recomendado

Fase 2: Mejora de Datos
  [ ] Registra 5+ fotos por alumno
  [ ] Diferentes ángulos y iluminaciones
  [ ] Verifica quality_metrics >= 0.6

Fase 3: Ajuste de Thresholds
  [ ] Pon optimal_threshold en /asistence
  [ ] Prueba con casos reales
  [ ] Mide: TP, FP, FN, TN

Fase 4: Validación
  [ ] Ejecuta diagnose.py nuevamente
  [ ] Verifica d-prime mejoró
  [ ] Chequea F1 score
```

---

## 📞 Soporte

**Si hay problemas:**

1. Revisa los logs:
   ```bash
   python diagnose.py 2>&1 | tee diagnose.log
   ```

2. Checks básicos:
   ```bash
   # ¿MongoDB corriendo?
   mongod --version
   
   # ¿PyTorch funciona?
   python -c "import torch; print(torch.cuda.is_available())"
   
   # ¿Modelo existe?
   ls -la ai_research/models/adaface_ir101_ms1mv3.ckpt
   ```

3. Reset completo (si nada funciona):
   ```bash
   # Elimina base de datos (⚠️ PIERDE TODOS LOS DATOS)
   mongo faceid --eval "db.dropDatabase()"
   
   # Reinicia API
   python backend_api/main.py
   ```

---

**¡Listo! Ya tienes un sistema de pre-procesamiento optimizado con diagnóstico automático. Empieza corriendo `python diagnose.py` 🚀**
