# PPM Mobile Flutter

Cliente movil Flutter para probar el flujo principal de PPM contra la API FastAPI actual.

## Objetivo de esta version

Esta app movil prioriza tres cosas:

- entender saldos en pocos segundos
- agregar gasto rapido desde el telefono
- mantener el detalle del grupo claro sin ruido visual

## Flujo incluido

- login
- registro
- URL base editable para apuntar a emulador o red local
- lista de grupos
- crear grupo
- resumen movil de saldo del grupo
- detalle de miembros
- lista de gastos
- seccion de saldos
- agregar gasto desde bottom sheet
- historial global simple
- cuenta y cierre de sesion

## Estructura

```text
frontend/
  lib/
    core/
      models/
      network/
      presentation/
      utils/
    features/
      app/
      auth/
      shell/
  test/
```

## Como correrlo

1. Instala Flutter SDK estable
2. Entra a `frontend/`
3. Corre:

```bash
flutter pub get
flutter run
```

## Como correrlo en tu telefono Android

En esta maquina ya quedo preparado el SDK en:

- `C:\Users\ultra\flutter-sdk`

Y el proyecto Android local ya apunta a:

- Flutter SDK: `C:\Users\ultra\flutter-sdk`
- Android SDK: `C:\Users\ultra\AppData\Local\Android\Sdk`

### Flujo recomendado

1. Conecta tu telefono por USB
2. Activa `Depuracion USB`
3. Acepta la huella RSA en el telefono
4. Desde la raiz del repo corre:

```bat
run_ppm_phone.bat
```

5. Luego, desde `frontend/`, corre:

```bat
run_phone.bat
```

Ese script detecta:

- el telefono por `adb`
- si puede usar `adb reverse` por USB para apuntar a `http://127.0.0.1:8000`
- si no puede, usa la IP local actual de tu computadora
- la URL final de backend para inyectarla a Flutter con `--dart-define`

Asi evitas editar manualmente `10.0.2.2` cuando usas telefono fisico.

## URLs utiles para pruebas

- Android emulator: `http://10.0.2.2:8000`
- Si usas telefono fisico: `http://TU_IP_LOCAL:8000`

Recuerda que el backend FastAPI debe seguir corriendo en tu computadora.

## Estado real de esta configuracion

Revision hecha el `2026-05-01` en esta maquina:

- `flutter doctor` ya detecta tu telefono `SM S911B`
- la IP local activa detectada en ese momento fue `192.168.100.83`
- faltan `cmdline-tools` del Android SDK y aceptar licencias para dejar el toolchain completamente limpio

Aunque eso sigue pendiente, el proyecto ya quedo encaminado para correr en dispositivo fisico.

## Siguiente paso recomendado

Cuando tengamos Flutter instalado en este entorno, lo siguiente es:

1. correr `flutter pub get`
2. levantar un emulador Android
3. validar login, lista de grupos, crear gasto y refresco de saldos
4. ajustar spacing, tipografia y formularios segun la primera prueba real en pantalla
