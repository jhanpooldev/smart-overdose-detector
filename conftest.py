"""
conftest.py — ROOT conftest.
Garantiza que STORAGE_BACKEND=memory se establece antes de cualquier
importacion de modulos src.* en todos los tests.
pytest carga este conftest.py primero al ser el mas cercano a pytest.ini.
"""
import os

# Forzar backend en memoria para TODOS los tests.
# load_dotenv en settings.py NO sobreescribe variables ya existentes en os.environ.
os.environ["STORAGE_BACKEND"] = "memory"
