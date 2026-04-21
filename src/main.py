from __future__ import annotations

import logging
import sys
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QObject, QSettings, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle


class ClipboardHelper(QObject):
    """Expose ``QGuiApplication.clipboard`` to QML via a context property."""

    @Slot(str)
    def setText(self, text: str):
        QGuiApplication.clipboard().setText(text or "")

from api.alerts_router import AlertsRouter
from api.ambient import AmbientClient
from api.blitzortung import BlitzortungClient
from api.ecowitt import EcowittClient
from api.hamqsl import HamQslClient
from api.no_station import NoStationClient
from api.open_meteo import OpenMeteoClient
from api.satellites import SatellitesClient
from api.space_weather import SpaceWeatherClient
from api.updates import UpdateChecker
from config import Config

APP_VERSION = "1.0.9"

logger = logging.getLogger(__name__)


def _make_weather_client():
    """Factory: picks the weather-station adapter based on saved ``stationType``.

    Credentials come from QSettings (populated via the Settings dialog). The
    Ambient adapter additionally falls back to ``.env`` via ``Config.load``.
    """
    QCoreApplication.setOrganizationName("wx-dashboard")
    QCoreApplication.setApplicationName("wx-dashboard")
    s = QSettings()
    station = str(s.value("stationType", "ambient") or "ambient").lower()

    if station == "none":
        logger.info("Weather station: None — using online sources (Open-Meteo)")
        return NoStationClient()

    if station == "ecowitt":
        logger.info("Weather station: Ecowitt (Cloud API v3)")
        return EcowittClient(
            application_key=str(s.value("ecowittAppKey",  "") or ""),
            api_key        =str(s.value("ecowittApiKey",  "") or ""),
            mac            =str(s.value("ecowittMac",     "") or ""),
            local_ip       =str(s.value("ecowittLocalIp", "") or ""),
        )

    if station != "ambient":
        logger.warning(
            "Station type '%s' is not yet implemented; using an idle "
            "AmbientClient so the UI still runs. Pick a supported brand "
            "or revert to Ambient in Settings.", station,
        )

    # Default path: Ambient Weather (reads .env then QSettings override)
    logger.info("Weather station: Ambient Weather Network")
    config = Config.load()
    return AmbientClient(config.application_key, config.api_key)


def resolve_bundle_root() -> Path:
    """Root directory for runtime resources (qml/, assets/).

    In development this is the project root. When frozen by PyInstaller,
    ``sys._MEIPASS`` is the extracted bundle directory.
    """
    if getattr(sys, "frozen", False):
        meipass = getattr(sys, "_MEIPASS", None)
        if meipass:
            return Path(meipass)
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    QGuiApplication.setOrganizationName("wx-dashboard")
    QGuiApplication.setApplicationName("wx-dashboard")

    app = QGuiApplication(sys.argv)
    QQuickStyle.setStyle("Basic")

    bundle_root = resolve_bundle_root()
    assets_dir  = bundle_root / "assets"
    qml_dir     = bundle_root / "qml"
    # qml/ in dev lives at src/qml/, not project root
    if not qml_dir.exists():
        qml_dir = Path(__file__).resolve().parent / "qml"

    weather      = _make_weather_client()
    hamqsl       = HamQslClient()
    forecast     = OpenMeteoClient()
    satellites   = SatellitesClient()
    blitzortung  = BlitzortungClient()
    alerts       = AlertsRouter()
    spaceWeather = SpaceWeatherClient()

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    clipboard      = ClipboardHelper()
    updateChecker  = UpdateChecker(APP_VERSION)
    ctx.setContextProperty("weatherClient",      weather)
    ctx.setContextProperty("hamqslClient",       hamqsl)
    ctx.setContextProperty("forecastClient",     forecast)
    ctx.setContextProperty("satellitesClient",   satellites)
    ctx.setContextProperty("blitzortungClient",  blitzortung)
    ctx.setContextProperty("alertsClient",       alerts)
    ctx.setContextProperty("spaceWeatherClient", spaceWeather)
    ctx.setContextProperty("clipboard",          clipboard)
    ctx.setContextProperty("updateChecker",      updateChecker)
    # Prefer the transparent version produced by tools/make_icon.py
    logo_file = assets_dir / "wxham_clean.png"
    if not logo_file.exists():
        logo_file = assets_dir / "wxham.png"
    ctx.setContextProperty(
        "appLogoUrl",
        QUrl.fromLocalFile(str(logo_file)).toString(),
    )

    engine.load(QUrl.fromLocalFile(str(qml_dir / "Main.qml")))

    if not engine.rootObjects():
        return -1

    weather.start()
    hamqsl.start()
    forecast.start()
    satellites.start()
    # Blitzortung only polls in None mode (logic gated in Main.qml), but
    # we start it unconditionally so setLocation/setRadius can prime it;
    # it's a no-op until a location is set.
    blitzortung.start()
    alerts.start()
    spaceWeather.start()

    exit_code = app.exec()
    weather.stop()
    hamqsl.stop()
    forecast.stop()
    satellites.stop()
    blitzortung.stop()
    alerts.stop()
    spaceWeather.stop()
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
