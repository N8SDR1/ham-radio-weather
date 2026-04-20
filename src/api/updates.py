"""Check GitHub for a newer release of this app.

Hits ``https://api.github.com/repos/<owner>/<repo>/releases/latest`` on demand,
compares ``tag_name`` with the app's current version, and emits a result
QML can bind to. No auto-check on startup; user triggers via the About dialog.
"""

from __future__ import annotations

import logging
import re
from typing import Optional

import httpx
from PySide6.QtCore import Property, QObject, Signal, Slot

logger = logging.getLogger(__name__)

# Tune these to wherever the project lives
REPO_OWNER = "N8SDR1"
REPO_NAME  = "ham-radio-weather"


def _parse_version(v: str) -> list[int]:
    """'v1.2.3' / '1.2.3' → [1, 2, 3]. Non-numeric parts ignored."""
    v = (v or "").strip().lstrip("vV")
    parts = re.split(r"[.\-_+]", v)
    out = []
    for p in parts:
        m = re.match(r"(\d+)", p)
        if m:
            out.append(int(m.group(1)))
    return out


def _is_newer(latest: str, current: str) -> bool:
    lat = _parse_version(latest)
    cur = _parse_version(current)
    # Pad so comparison doesn't short-circuit on different lengths
    n = max(len(lat), len(cur))
    lat += [0] * (n - len(lat))
    cur += [0] * (n - len(cur))
    return lat > cur


class UpdateChecker(QObject):
    """One-shot GitHub release checker. Triggered by QML."""

    # status: "idle" | "checking" | "up_to_date" | "update_available" | "error"
    statusChanged   = Signal()
    resultReady     = Signal(str, str, str)   # (status, latestTag, releaseUrl)

    URL_TEMPLATE = "https://api.github.com/repos/{owner}/{repo}/releases/latest"

    def __init__(self, current_version: str, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._current_version = current_version
        self._status: str = "idle"
        self._latest_tag: str = ""
        self._release_url: str = ""
        self._message: str = ""

    @Slot()
    def check(self):
        self._set("checking", "", "", "")
        try:
            url = self.URL_TEMPLATE.format(owner=REPO_OWNER, repo=REPO_NAME)
            headers = {
                "Accept": "application/vnd.github+json",
                "User-Agent": f"ham-radio-weather/{self._current_version}",
            }
            with httpx.Client(timeout=10.0, headers=headers) as client:
                r = client.get(url)
                if r.status_code == 404:
                    self._set("no_releases", "", "", "No releases published yet.")
                    return
                r.raise_for_status()
                data = r.json()
        except Exception as e:
            logger.warning("Update check failed: %s", e)
            self._set("error", "", "", f"Could not reach GitHub: {e}")
            return

        tag = str(data.get("tag_name") or "")
        url_html = str(data.get("html_url") or "")
        if not tag:
            self._set("error", "", "", "Release had no tag name")
            return

        if _is_newer(tag, self._current_version):
            self._set("update_available", tag, url_html,
                      f"New release {tag} is available")
        else:
            self._set("up_to_date", tag, url_html,
                      f"You're on the latest release ({self._current_version})")

    def _set(self, status: str, tag: str, url: str, message: str):
        self._status      = status
        self._latest_tag  = tag
        self._release_url = url
        self._message     = message
        self.statusChanged.emit()
        self.resultReady.emit(status, tag, url)

    # QML-visible properties -----------------------------------------------

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=statusChanged)
    def latestTag(self):
        return self._latest_tag

    @Property(str, notify=statusChanged)
    def releaseUrl(self):
        return self._release_url

    @Property(str, notify=statusChanged)
    def message(self):
        return self._message

    @Property(str, constant=True)
    def currentVersion(self):
        return self._current_version

    @Property(str, constant=True)
    def repoUrl(self):
        return f"https://github.com/{REPO_OWNER}/{REPO_NAME}"
