"""
in_memory_settings_repository.py — Repositorio en memoria para configuración de usuarios.
"""
from typing import Dict

class InMemorySettingsRepository:
    def __init__(self):
        # key: user_id, value: dict de settings
        self._settings: Dict[str, dict] = {}
        
    def get_by_user_id(self, user_id: str) -> dict:
        return self._settings.get(user_id, {"min_bpm": 50, "max_bpm": 120})

    def update(self, user_id: str, min_bpm: int, max_bpm: int) -> dict:
        self._settings[user_id] = {
            "min_bpm": min_bpm,
            "max_bpm": max_bpm
        }
        return self._settings[user_id]
