from __future__ import annotations

import logging
import os
import sys
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv
from PySide6.QtCore import QCoreApplication, QSettings

logger = logging.getLogger(__name__)


def _runtime_root() -> Path:
    """Root for runtime config (where .env lives at install time)."""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


PROJECT_ROOT = _runtime_root()


@dataclass(frozen=True)
class Config:
    application_key: str
    api_key: str

    @classmethod
    def load(cls) -> "Config":
        """Load Ambient keys from .env first, then fall back to QSettings overrides.

        Returns empty strings if nothing is configured — AmbientClient will skip
        REST polling and the user will see empty tiles until they enter keys
        via Settings → Ambient Weather (and restart).
        """
        env_path = PROJECT_ROOT / ".env"
        if env_path.exists():
            load_dotenv(env_path)

        app_key = os.getenv("AMBIENT_APPLICATION_KEY", "").strip()
        api_key = os.getenv("AMBIENT_API_KEY", "").strip()

        # Fall back to QSettings overrides
        if not app_key or not api_key:
            QCoreApplication.setOrganizationName("wx-dashboard")
            QCoreApplication.setApplicationName("wx-dashboard")
            s = QSettings()
            app_key = app_key or str(s.value("ambientAppKey", "") or "").strip()
            api_key = api_key or str(s.value("ambientApiKey", "") or "").strip()

        if not app_key or not api_key:
            logger.warning(
                "No Ambient keys found in .env or saved settings. "
                "Open Settings → Ambient Weather to configure and restart."
            )

        return cls(application_key=app_key, api_key=api_key)
