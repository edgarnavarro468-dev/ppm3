# PPM - Finanzas Sociales

PPM es una app web para organizar gastos, decisiones y planes entre amigos sin perder el contexto social del grupo.

La idea no es solo registrar deudas: tambien permite proponer actividades, votar opciones, elegir planes, llevar feed de actividad y marcar liquidaciones.

## Que hace hoy

- Registro e inicio de sesion
- Creacion de grupos
- Rol de anfitrion para quien crea el grupo
- Agregar miembros al grupo
- Registrar gastos compartidos
- Ver balances entre usuarios
- Marcar liquidaciones manuales
- Feed social del grupo
- Propuestas con votacion y seleccion
- Tipos de propuesta: comida, actividad y lugar
- Datos de proveedor y especificaciones de pago
- Calificacion de usuarios con titulos
- Eliminacion de deudas por votacion
- Eliminacion de grupos por decision colectiva
- Limite de 1,000,000 MXN por operacion

## Stack

- Backend: FastAPI
- Base de datos: SQLite + SQLAlchemy
- Frontend web: HTML, CSS y JavaScript vanilla

## Estructura del proyecto

```text
backend/
  database.py      Modelos y conexion a SQLite
  main.py          API FastAPI y montaje de la web
  security.py      Hash y verificacion de contraseñas

web/
  index.html       Interfaz principal
  styles.css       Estilos de la app
  app.js           Logica del frontend

ppm.db             Base de datos local
run_ppm.bat        Arranque rapido en Windows
requirements.txt   Dependencias del backend
```

Nota: la interfaz activa del proyecto es la carpeta `web/`, servida por FastAPI en `/app/`.

## Requisitos

- Windows con PowerShell
- Python 3.11 o superior
- Entorno virtual `.venv` creado

## Instalacion local

Si aun no tienes el entorno listo:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Si PowerShell bloquea la activacion:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

## Como correr la app

### Opcion 1: launcher

Haz doble clic en:

- [run_ppm.bat](C:/Users/edgar/Documents/Codex/2026-04-26/files-mentioned-by-the-user-propuesta/run_ppm.bat)

### Opcion 2: manual

```powershell
cd "C:\Users\edgar\Documents\Codex\2026-04-26\files-mentioned-by-the-user-propuesta"
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Luego abre:

- [http://localhost:8000/app/](http://localhost:8000/app/)

Si el puerto `8000` falla, prueba con `8010`:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8010
```

Y abre:

- [http://localhost:8010/app/](http://localhost:8010/app/)

## Como compartirla con amigos usando ngrok

1. Levanta la app localmente
2. En otra terminal corre:

```powershell
ngrok http 8000
```

3. ngrok te va a dar una URL publica como:

```text
https://algo.ngrok-free.app
```

4. Comparte esta ruta:

```text
https://algo.ngrok-free.app/app/
```

Importante:

- El backend debe seguir corriendo localmente
- La ventana de ngrok debe quedarse abierta
- Si se cierra cualquiera de las dos, el link deja de funcionar

## Rutas principales de la API

### Autenticacion

- `POST /auth/register`
- `POST /auth/login`

### Usuarios

- `GET /users`
- `GET /users/{user_id}/contacts`
- `POST /users/{user_id}/contacts`
- `GET /users/{user_id}/groups`
- `GET /users/{user_id}/summary`

### Grupos

- `POST /groups`
- `GET /groups/{group_id}`
- `POST /groups/{group_id}/members`
- `POST /groups/{group_id}/delete-vote`

### Gastos y balances

- `GET /groups/{group_id}/expenses`
- `POST /expenses`
- `POST /expenses/{expense_id}/delete-vote`
- `GET /groups/{group_id}/balances`
- `GET /groups/{group_id}/settlements`
- `POST /groups/{group_id}/settlements`
- `POST /settlements/{settlement_id}/confirm`

### Feed y propuestas

- `GET /groups/{group_id}/feed`
- `GET /groups/{group_id}/proposals`
- `POST /groups/{group_id}/proposals`
- `POST /proposals/{proposal_id}/vote`
- `POST /proposals/{proposal_id}/select`

### Comunidad

- `GET /groups/{group_id}/ratings`
- `POST /groups/{group_id}/ratings`
- `GET /groups/{group_id}/stats`

## Reglas importantes del negocio

- El creador del grupo se considera anfitrion
- Una operacion no puede exceder `1,000,000 MXN`
- Las propuestas pueden ser de comida, actividad o lugar
- Las deudas pueden eliminarse por votacion
- Los grupos pueden eliminarse por decision colectiva
- Las liquidaciones se pueden marcar manualmente

## Problemas comunes

### `ERR_CONNECTION_REFUSED`

La app no esta corriendo. Levanta primero el backend con `uvicorn`.

### `WinError 10013`

El puerto esta ocupado o bloqueado. Prueba otro puerto como `8010`.

### ngrok abre pero la web no carga

Normalmente significa que `ngrok` si esta funcionando, pero el backend local no esta levantado.

## Estado actual

Este repo ya funciona como MVP web para validar interaccion entre amigos antes de pasar a una app movil.

Las siguientes mejoras naturales serian:

- notificaciones
- invitaciones mas pulidas
- roles mas finos
- historial de pagos mas completo
- despliegue publico estable sin depender de ngrok
