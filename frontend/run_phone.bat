@echo off
setlocal EnableExtensions EnableDelayedExpansion
title PPM Mobile - Ejecutar en telefono

set "FLUTTER_CMD=C:\Users\ultra\flutter-sdk\bin\flutter.bat"
if not exist "%FLUTTER_CMD%" (
    set "FLUTTER_CMD=flutter"
)

set "ADB_CMD=C:\Users\ultra\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB_CMD%" (
    set "ADB_CMD=adb"
)

set "LOCAL_IP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -ExpandProperty IPAddress -First 1)"`) do (
    set "LOCAL_IP=%%I"
)

if "%LOCAL_IP%"=="" (
    set "LOCAL_IP=192.168.100.83"
)

set "DEVICE_ID="
for /f "skip=1 tokens=1,2" %%A in ('"%ADB_CMD%" devices') do (
    if "%%B"=="device" (
        set "DEVICE_ID=%%A"
        goto :device_found
    )
)

:device_found
if "%DEVICE_ID%"=="" (
    echo No se detecto un telefono Android por adb.
    echo Activa Depuracion USB, conecta el telefono y acepta el permiso en pantalla.
    pause
    exit /b 1
)

echo ========================================
echo   PPM Mobile en telefono Android
echo ========================================
echo.
echo Telefono detectado: %DEVICE_ID%
set "API_URL=http://%LOCAL_IP%:8000"

"%ADB_CMD%" reverse tcp:8000 tcp:8000 >nul 2>nul
if %errorlevel%==0 (
    set "API_URL=http://127.0.0.1:8000"
    echo Modo USB detectado con adb reverse.
) else (
    echo adb reverse no estuvo disponible. Se usara la red local.
)

echo API configurada:   %API_URL%
echo.
echo Antes de seguir, deja corriendo:
echo   C:\Users\ultra\ppm-mony\ppm3\run_ppm_phone.bat
echo.

call "%FLUTTER_CMD%" run -d %DEVICE_ID% --dart-define=PPM_API_URL=%API_URL%
