@echo off
REM Ham Weather Dashboard — silent launcher (no console window)
setlocal
cd /d "%~dp0"
start "" ".venv\Scripts\pythonw.exe" "src\main.py"
endlocal
