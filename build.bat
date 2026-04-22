@echo off
REM =====================================================================
REM Ham Radio Weather — full build pipeline
REM   1) activate venv
REM   2) generate icon.ico from assets/wxham.png
REM   3) bundle with PyInstaller
REM   4) wrap with Inno Setup
REM =====================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

if not exist ".venv\Scripts\activate.bat" (
    echo [ERROR] venv not found. Run: python -m venv .venv ^&^& .venv\Scripts\activate ^&^& pip install -r requirements.txt
    exit /b 1
)

echo.
echo [1/4] Activating venv...
call .venv\Scripts\activate.bat || exit /b 1

echo.
echo [2/4] Generating icon.ico from assets\wxham.png...
python tools\make_icon.py
if errorlevel 1 (
    echo [ERROR] Icon generation failed. Make sure Pillow is installed: pip install Pillow
    exit /b 1
)

echo.
echo [3/4] Running PyInstaller...
if exist "build" rmdir /s /q "build"
if exist "dist\HamRadioWeather" rmdir /s /q "dist\HamRadioWeather"
pyinstaller --noconfirm wx-dashboard.spec
if errorlevel 1 (
    echo [ERROR] PyInstaller build failed.
    exit /b 1
)

echo.
echo [4/4] Building Windows installer with Inno Setup...
set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "!ISCC!" set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
if not exist "!ISCC!" (
    echo [WARN] Inno Setup not found. Skipping installer step.
    echo        Install from https://jrsoftware.org/isinfo.php
    echo        Then run:  "%%ProgramFiles(x86)%%\Inno Setup 6\ISCC.exe" installer.iss
    echo.
    echo Bundle is ready at: dist\HamRadioWeather\
    exit /b 0
)
"!ISCC!" installer.iss
if errorlevel 1 (
    echo [ERROR] Inno Setup compile failed.
    exit /b 1
)

echo.
echo ============================================
echo  Build complete!
echo    Bundle:    dist\HamRadioWeather\
echo    Installer: dist\installer\HamRadioWeather-Setup-1.0.10.exe
echo ============================================
endlocal
