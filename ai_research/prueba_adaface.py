import torch
import sys
import os

# 1. LOCALIZACIÓN DINÁMICA
ruta_base = os.path.dirname(os.path.abspath(__file__))
sys.path.append(ruta_base)

# 2. CONFIGURACIÓN DE ALTO RENDIMIENTO (RTX 5060 Ti)
# Aquí es donde ponemos el primer bloque que mencionaste
device = torch.device('cuda')
torch.backends.cudnn.benchmark = True # Optimiza el rendimiento para tu GPU

try:
    from ai_research.model import common
    print("✅ Código de arquitectura (common.py) detectado.")
except ImportError:
    print(f"❌ ERROR: No se encuentra 'common.py' en: {os.path.join(ruta_base, 'model')}")
    sys.exit()

# 3. CREAR EL MODELO EN FP16 (Aquí va el segundo bloque)
# El .half() hace que use menos VRAM y sea más rápido en tu 5060 Ti
model = common.iresnet101(num_features=512).to(device).half() 

# 4. CARGAR PESOS DE MS1MV3 (El "cerebro" nuevo que descargaste)
nombre_pesos = 'adaface_ir101_ms1mv3.ckpt'
ruta_pesos = os.path.join(ruta_base, 'weights', nombre_pesos)

if os.path.exists(ruta_pesos):
    try:
        # Aquí va el tercer bloque de carga
        checkpoint = torch.load(ruta_pesos, map_location=device)
        state_dict = checkpoint['state_dict'] if 'state_dict' in checkpoint else checkpoint
        
        # Limpieza de llaves para que coincidan con tu arquitectura
        new_state_dict = {}
        for k, v in state_dict.items():
            name = k[6:] if k.startswith('model.') else k
            new_state_dict[name] = v
            
        # El bloque de carga final que pediste
        model.load_state_dict(new_state_dict, strict=False)
        model.eval()
        print(f"✅ ¡SISTEMA ACTUALIZADO! Usando dataset MS1MV3.")
        print(f"🚀 OPTIMIZADO PARA RTX 5060 Ti (FP16 Activo)")
    except Exception as e:
        print(f"❌ Error al cargar los pesos: {e}")
else:
    print(f"❌ ARCHIVO NO ENCONTRADO EN: {ruta_pesos}")