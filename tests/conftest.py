"""
conftest.py — Configura STORAGE_BACKEND=memory ANTES de cualquier importacion de src.
pytest garantiza que conftest.py se carga antes que los archivos de test.
"""
import os

# CRITICO: Establecer en os.environ ANTES de que settings.py sea importado.
# load_dotenv no sobreescribe variables ya definidas en os.environ.
os.environ["STORAGE_BACKEND"] = "memory"
