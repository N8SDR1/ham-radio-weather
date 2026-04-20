# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for Ham Radio Weather.
#
# Produces a one-folder distribution at dist/HamRadioWeather/.
# Run with:  pyinstaller --noconfirm wx-dashboard.spec

from pathlib import Path

ROOT = Path(SPEC).resolve().parent

datas = [
    (str(ROOT / "src" / "qml"), "qml"),
    (str(ROOT / "assets"),      "assets"),
]

hiddenimports = [
    "sgp4",
    "sgp4.api",
    "sgp4.propagation",
    "sgp4.earth_gravity",
    "socketio",
    "engineio",
    "engineio.async_drivers.threading",
    "httpx",
    "dotenv",
]

block_cipher = None

a = Analysis(
    [str(ROOT / "src" / "main.py")],
    pathex=[str(ROOT), str(ROOT / "src")],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
    cipher=block_cipher,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="HamRadioWeather",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    icon=str(ROOT / "assets" / "icon.ico"),
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name="HamRadioWeather",
)
