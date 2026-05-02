@echo off
setlocal EnableExtensions EnableDelayedExpansion
title PPM - Backend para telefono

echo ========================================
echo    PPM - Backend para telefono fisico
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

if "%PYTHON_CMD%"=="" (
    echo No se encontro Python en este equipo.
    echo Instala Python 3.11+ o agrega python/py al PATH.
    pause
    exit /b 1
)

set "LOCAL_IP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -ExpandProperty IPAddress -First 1)"`) do (
    set "LOCAL_IP=%%I"
)

if "%LOCAL_IP%"=="" (
    set "LOCAL_IP=192.168.100.83"
)

echo Iniciando backend en toda la red local...
start "PPM Phone Backend" /min cmd /k "%PYTHON_CMD% -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000"

echo.
echo Backend local:
echo   http://127.0.0.1:8000/app/
echo.
echo Backend para tu telefono:
echo   http://%LOCAL_IP%:8000
echo.
echo En el telefono usa esa URL dentro de la app si no lanzas Flutter con el script del frontend.
echo Tu PC y tu telefono deben estar en la misma red Wi-Fi.
echo.
pause
