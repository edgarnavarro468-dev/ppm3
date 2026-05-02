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

## URLs utiles para pruebas

- Android emulator: `http://10.0.2.2:8000`
- Si usas telefono fisico: `http://TU_IP_LOCAL:8000`

Recuerda que el backend FastAPI debe seguir corriendo en tu computadora.

## Siguiente paso recomendado

Cuando tengamos Flutter instalado en este entorno, lo siguiente es:

1. correr `flutter pub get`
2. levantar un emulador Android
3. validar login, lista de grupos, crear gasto y refresco de saldos
4. ajustar spacing, tipografia y formularios segun la primera prueba real en pantalla
