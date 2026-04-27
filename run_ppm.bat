@echo off
title PPM - Finanzas Sociales

echo ========================================
echo         PPM - Finanzas Sociales
echo ========================================
echo.

set "PYTHON_CMD="
where py >nul 2>nul
if %errorlevel%==0 (
    set "PYTHON_CMD=py"
) else (
    where python >nul 2>nul
    if %errorlevel%==0 (
        set "PYTHON_CMD=python"
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

if not exist ".localdeps" (
    echo Instalando dependencias locales...
    %PYTHON_CMD% -m pip install -r requirements.txt --target .localdeps
    if errorlevel 1 (
        echo No se pudieron instalar las dependencias.
        pause
        exit /b 1
    )
)

echo Iniciando backend en http://localhost:8000
start "PPM Backend" /min cmd /k "%PYTHON_CMD% backend\run_backend.py"

timeout /t 2 /nobreak > nul

echo Iniciando frontend en http://localhost:8501
start "PPM Frontend" /min cmd /k "%PYTHON_CMD% frontend\run_frontend.py"

echo.
echo Backend:  http://localhost:8000
echo Frontend: http://localhost:8501
echo.
echo Puedes cerrar esta ventana. La app seguira en las otras dos.
