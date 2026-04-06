#!/usr/bin/env python3
"""
Script para validar todas las dependencias del proyecto Face-ID-Edge-AI
"""

import sys
import subprocess

# Diccionario de librerías a verificar con sus nombres de importación
DEPENDENCIES = {
    # Backend API & Core
    'fastapi': 'fastapi',
    'uvicorn': 'uvicorn',
    'pydantic': 'pydantic',
    'motor': 'motor',
    'anyio': 'anyio',
    'pillow': 'PIL',
    'numpy': 'numpy',
    'torch': 'torch',
    'opencv-python': 'cv2',
    'pyngrok': 'pyngrok',
    
    # ML/AI
    'pytorch-lightning': 'pytorch_lightning',
    'tqdm': 'tqdm',
    'bcolz-zipline': 'bcolz',
    'prettytable': 'prettytable',
    'menpo': 'menpo',
    'mxnet': 'mxnet',
    
    # Validation & Utils
    'scikit-learn': 'sklearn',
    'scipy': 'scipy',
    
    # Standard library (siempre disponibles)
    'json': 'json',
    'os': 'os',
    'asyncio': 'asyncio',
}

def check_import(package_name, import_name):
    """Intenta importar un paquete y retorna True si es exitoso"""
    try:
        __import__(import_name)
        return True, None
    except ImportError as e:
        return False, str(e)
    except Exception as e:
        return False, f"Error inesperado: {str(e)}"

def get_package_version(package_name):
    """Obtiene la versión instalada de un paquete"""
    try:
        result = subprocess.run(
            [sys.executable, '-m', 'pip', 'show', package_name],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if line.startswith('Version:'):
                    return line.split(':', 1)[1].strip()
        return "desconocida"
    except Exception:
        return "no disponible"

def main():
    print("=" * 80)
    print("VALIDACIÓN DE DEPENDENCIAS - Face-ID-Edge-AI")
    print("=" * 80)
    print()
    
    failed_imports = []
    successful_imports = []
    
    for package_name, import_name in DEPENDENCIES.items():
        success, error = check_import(package_name, import_name)
        version = get_package_version(package_name) if success else "NO INSTALADA"
        
        status = "✓ OK" if success else "✗ ERROR"
        print(f"{status} | {package_name:25} | {import_name:20} | v{version}")
        
        if success:
            successful_imports.append((package_name, import_name, version))
        else:
            failed_imports.append((package_name, import_name, error))
    
    print()
    print("=" * 80)
    print(f"RESUMEN: {len(successful_imports)}/{len(DEPENDENCIES)} dependencias correctas")
    print("=" * 80)
    print()
    
    if failed_imports:
        print("❌ LIBRERÍAS CON ERRORES:")
        print("-" * 80)
        for package, import_name, error in failed_imports:
            print(f"  • {package} ({import_name})")
            print(f"    Error: {error}")
            print()
        
        print("SOLUCIONES RECOMENDADAS:")
        print("-" * 80)
        print("Ejecuta los siguientes comandos para instalar las librerías faltantes:")
        print()
        for package, _, _ in failed_imports:
            print(f"  pip install {package}")
        print()
        return 1
    else:
        print("✓ TODAS LAS DEPENDENCIAS ESTÁN CORRECTAMENTE INSTALADAS")
        print()
        print("Estado del entorno:")
        print("-" * 80)
        print(f"  • Python: {sys.version.split()[0]}")
        print(f"  • Ubicación: {sys.executable}")
        print(f"  • Librerías exitosas: {len(successful_imports)}")
        print()
        return 0

if __name__ == '__main__':
    sys.exit(main())
