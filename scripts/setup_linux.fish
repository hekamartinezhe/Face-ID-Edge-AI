#!/usr/bin/fish
echo "--- Configurando entorno para Face-ID (Linux/Fish) ---"

# Crear y activar venv
python -m venv venv
source venv/bin/activate.fish

# Instalar dependencias
pip install --upgrade pip
pip install fastapi uvicorn requests python-multipart numpy torch torchvision torchaudio

echo "--- Entorno listo. Usa 'source venv/bin/activate.fish' para trabajar ---"