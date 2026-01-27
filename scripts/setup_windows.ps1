Write-Host "--- Configurando entorno Face-ID (Windows) ---" -ForegroundColor Cyan
python -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install fastapi uvicorn requests python-multipart numpy torch torchvision torchaudio
Write-Host "--- Listo. Usa '.\venv\Scripts\Activate.ps1' ---" -ForegroundColor Green