@echo off
title PPM - Web Finanzas Sociales

echo ========================================
echo       PPM - Web Finanzas Sociales
echo ========================================
echo.

set "PYTHON_CMD="

if exist ".venv\Scripts\python.exe" (
    set "PYTHON_CMD=.venv\Scripts\python.exe"
)

if "%PYTHON_CMD%"=="" (
    where py >nul 2>nul
    if %errorlevel%==0 (
        set "PYTHON_CMD=py"
    ) else (
        where python >nul 2>nul
        if %errorlevel%==0 (
            set "PYTHON_CMD=python"
        )
    )
)

if "%PYTHON_CMD%"=="" if exist "C:\Users\edgar\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" (
    set "PYTHON_CMD=C:\Users\edgar\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
)

if "%PYTHON_CMD%"=="" (
    echo No se encontro Python en este equipo.
    echo Instala Python 3.11+ o agrega python/py al PATH.
    pause
    exit /b 1
)

echo Iniciando servidor web en http://localhost:8000/app/
start "PPM Web" /min cmd /k "%PYTHON_CMD% -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000"

echo.
echo App web:  http://localhost:8000/app/
echo API:      http://localhost:8000
echo.
echo Puedes cerrar esta ventana. La app seguira corriendo en la otra.
