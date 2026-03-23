import os
import cv2
import torch
import time
import sys

# Forzar que Python busque en el directorio actual para evitar ModuleNotFoundError
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from inference import AdaFaceInference
except ImportError as e:
    print(f"❌ Error de importación: {e}")
    print("Asegúrate de haber guardado el nuevo inference.py con la clase AdaFaceInference.")
    sys.exit(1)

def registrar_asistencia(nombre, score):
    """Simula el registro en una base de datos o archivo log"""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"📝 [LOG] {timestamp} - Sujeto: {nombre} - Confianza: {score:.4f}")

def main():
    # --- 1. CONFIGURACIÓN ---
    # Asegúrate de que este archivo exista en la carpeta models/
    MODEL_PATH = 'models/adaface_ir101_ms1mv3.ckpt'
    TEST_IMAGE = 'data_collector/test_images/prueba.jpg'
    UMBRAL = 0.45
    
    print("--- 🚀 INICIANDO SISTEMA FACE-ID (EDGE AI) ---")

    # --- 2. HARDWARE CHECK (RTX 5060 Ti) ---
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    if device == 'cuda':
        gpu_name = torch.cuda.get_device_name(0)
        print(f"✅ Hardware acelerado detectado: {gpu_name}")
    else:
        print("⚠️ Advertencia: No se detectó CUDA. Corriendo en CPU (será lento).")

    # --- 3. INICIALIZAR MOTOR DE INFERENCIA ---
    print(f"🧠 Cargando AdaFace (ir_101) en memoria...")
    try:
        # Pasamos ir_101 porque tu .ckpt dice que es esa arquitectura
        engine = AdaFaceInference(
            model_path=MODEL_PATH, 
            architecture='ir_101', 
            device=device
        )
    except Exception as e:
        print(f"❌ Error crítico cargando el modelo: {e}")
        return

    # --- 4. CARGAR IMAGEN DE PRUEBA ---
    if not os.path.exists(TEST_IMAGE):
        print(f"⚠️ Error: No encontré la imagen en {TEST_IMAGE}")
        return

    frame = cv2.imread(TEST_IMAGE)
    if frame is None:
        print("⚠️ Error: El archivo de imagen está corrupto o no se puede leer.")
        return
    
    # --- 5. INFERENCIA Y RESULTADOS ---
    print(f"🔍 Procesando frame: {os.path.basename(TEST_IMAGE)}...")
    start_time = time.time()
    
    try:
        # El método run_inference ahora hace el face alignment internamente
        nombre_detectado, score = engine.run_inference(frame) 
        
        end_time = time.time()
        ms = (end_time - start_time) * 1000
        print(f"⏱️ Tiempo de ejecución: {ms:.2f} ms")

        if score > UMBRAL:
            print(f"✅ RESULTADO: {nombre_detectado.upper()} reconocido.")
            registrar_asistencia(nombre_detectado, score)
        else:
            print(f"🚫 RESULTADO: Rostro no reconocido o confianza muy baja ({score:.4f})")
            
    except Exception as e:
        print(f"❌ Error durante el proceso de inferencia: {e}")

if __name__ == "__main__":
    main()
