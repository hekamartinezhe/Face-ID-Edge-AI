
## 📂 Estructura del Monorepo

- `app_mobile/`: Cliente en Flutter para captura y visualización.
- `backend_api/`: Servidor FastAPI (inferencia y lógica de negocio).
- `ai_research/`: Scripts de entrenamiento y optimización en PyTorch.
- `shared/`: Modelos `.pth` y recursos compartidos.
- `scripts/`: Automatización de entorno para el equipo.

---

##  Configuración del Entorno

### Linux (CachyOS / Fish Shell)

#### Dar permisos de ejecución y ejecutar
```fish
chmod +x scripts/setup_linux.fish
setup linux.fish
```

### Windows / Powershell

#### Dar permiso de ejecución y ejecutar

```Powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\setup_windows.ps1
.\venv\Scripts\Activate.ps1
```