# PPM - Finanzas Sociales

## Product & Technical Specification (MVP)

**Version:** Interna MVP  
**Fecha:** 29 de abril de 2026  
**Estado:** Validacion con usuarios reales (beta cerrada)

## 1. Resumen del producto

PPM es una plataforma web para la gestion de dinero en grupos sociales, donde los gastos compartidos, decisiones y dinamicas sociales coexisten en un mismo sistema.

A diferencia de apps tradicionales de split de gastos, PPM introduce:

- votaciones grupales
- propuestas de actividades
- reputacion de usuarios
- eliminacion colectiva de deudas y decisiones

El objetivo del MVP es validar si los grupos de amigos pueden coordinar dinero y decisiones sociales dentro de una sola plataforma sin friccion.

## 2. Alcance del MVP

### Incluye

- Autenticacion de usuarios
- Creacion y gestion de grupos
- Registro de gastos compartidos
- Calculo automatico de balances
- Liquidaciones manuales
- Sistema de propuestas (actividad, comida, lugar)
- Votaciones de grupo
- Feed de actividad del grupo
- Sistema basico de reputacion
- Eliminacion de deudas por votacion

### No incluye

- App movil
- Pagos reales integrados (Stripe / SPEI)
- Notificaciones push
- Algoritmos avanzados de credito
- Multi-moneda
- Escalamiento cloud

## 3. Principios de diseno del sistema

- **Social-first:** el dinero es consecuencia de decisiones del grupo
- **Transparencia total:** todas las acciones son visibles en el feed
- **Democratico:** decisiones criticas requieren votacion
- **Trazabilidad:** todo gasto o liquidacion tiene historial
- **MVP rapido:** simplicidad sobre escalabilidad

## 4. Entidades principales del sistema

### User

- `id`
- `name`
- `email`
- `password_hash`
- `reputation_score`
- `created_at`

### Group

- `id`
- `name`
- `host_user_id`
- `created_at`

### GroupMember

- `user_id`
- `group_id`
- `role` (`host` / `member`)

### Expense

- `id`
- `group_id`
- `created_by`
- `amount`
- `description`
- `participants`
- `status` (`active` / `disputed` / `deleted_pending`)
- `created_at`

### Balance

- `user_id`
- `group_id`
- `balance_amount`

### Settlement

- `id`
- `group_id`
- `from_user`
- `to_user`
- `amount`
- `status` (`pending` / `confirmed`)

### Proposal

- `id`
- `group_id`
- `type` (`food` / `activity` / `place`)
- `title`
- `provider`
- `payment_method`
- `deadline`
- `scheduled_date`
- `status` (`open` / `selected` / `rejected`)

### Vote

- `id`
- `proposal_id`
- `user_id`
- `value` (`yes` / `no`)

## 5. Reglas de negocio

### 5.1 Gastos

- Un gasto puede incluir multiples participantes
- El total se divide automaticamente entre participantes
- Cada gasto actualiza balances individuales

### 5.2 Balances

- Balance positivo = te deben dinero
- Balance negativo = debes dinero
- Los balances se recalculan en tiempo real

### 5.3 Liquidaciones

- Una liquidacion es un pago entre usuarios
- Debe ser confirmada manualmente
- Al confirmarse, ajusta balances

### 5.4 Propuestas

- Cualquier miembro puede crear propuesta
- Se requiere votacion de mayoria simple para seleccionar
- Solo una propuesta puede ser activa por categoria y fecha

### 5.5 Eliminacion de deudas y gastos

- Requiere votacion del grupo
- Se elimina del sistema pero queda en historial

### 5.6 Reputacion

- Aumenta por participacion activa y pagos cumplidos
- Disminuye por deudas o conflictos no resueltos

## 6. Arquitectura tecnica

### Backend

- FastAPI (Python)
- SQLAlchemy ORM
- SQLite (`ppm.db`)

### Frontend

- HTML
- CSS
- JavaScript vanilla

### Arquitectura general

- El backend sirve API y frontend estatico
- El frontend consume API directamente
- No hay separacion SPA / frontend framework

## 7. Estructura del proyecto

```text
backend/
  main.py          -> API + server web
  database.py      -> modelos + conexion SQLite
  security.py      -> hashing de contrasenas

web/
  index.html       -> UI principal
  styles.css       -> estilos
  app.js           -> logica frontend

ppm.db             -> base de datos local
run_ppm.bat        -> script de ejecucion
```

## 8. API Overview

### Auth

- `POST /auth/register`
- `POST /auth/login`

### Users

- `GET /users`
- `GET /users/{id}/summary`
- `GET /users/{id}/groups`

### Groups

- `POST /groups`
- `GET /groups/{id}`
- `POST /groups/{id}/members`

### Expenses

- `POST /expenses`
- `GET /groups/{id}/expenses`

### Balances

- `GET /groups/{id}/balances`

### Settlements

- `POST /settlements`
- `POST /settlements/{id}/confirm`

### Proposals

- `POST /groups/{id}/proposals`
- `POST /proposals/{id}/vote`
- `POST /proposals/{id}/select`

### Feed

- `GET /groups/{id}/feed`

## 9. Flujo del sistema

### Flujo de gasto

1. Usuario crea gasto
2. Define participantes
3. Sistema divide monto
4. Actualiza balances
5. Evento aparece en feed

### Flujo de propuesta

1. Usuario crea propuesta
2. Grupo vota
3. Se selecciona opcion ganadora
4. Se agenda evento

### Flujo de liquidacion

1. Usuario propone pago
2. Se registra settlement
3. Otro usuario confirma
4. Balance se ajusta

## 10. Infraestructura de desarrollo

### Local

```powershell
uvicorn backend.main:app --reload --port 8000
```

### Acceso

- `http://localhost:8000/app/`

### Exposicion publica

```powershell
ngrok http 8000
```

## 11. Limitaciones actuales

- Base de datos no escalable (SQLite)
- Sin control de concurrencia avanzado
- Sin autenticacion JWT robusta
- Sin sistema de roles avanzado
- Sin backend distribuido
- Sin logs centralizados

## 12. Riesgos del sistema

- Conflictos en balances en grupos grandes
- Manipulacion de votaciones
- Falta de auditoria avanzada
- Dependencia de confianza entre usuarios
- Posible inconsistencia en liquidaciones simultaneas

## 13. Proximas iteraciones

### Corto plazo

- Notificaciones internas
- Mejor sistema de invitaciones
- Mejora de reputacion
- Validacion de reglas de gasto

### Medio plazo

- Migracion a PostgreSQL
- Sistema de roles (`admin`, `auditor`)
- API mas robusta (versionada)

### Largo plazo

- App movil
- Pagos reales integrados
- Sistema de credito social interno
- Escalamiento cloud

## 14. Estado del MVP

El sistema esta en fase de beta funcional para validacion de comportamiento social y coordinacion financiera en grupos reales.

## Veredicto

Esto ya no es solo una idea. Es un sistema definido que:

- puede mostrarse a un dev senior sin explicacion extra
- sirve como base de onboarding
- puede evolucionar a pitch tecnico

Lo mas importante es que ya existe una separacion clara entre producto, reglas del sistema y base tecnica.
