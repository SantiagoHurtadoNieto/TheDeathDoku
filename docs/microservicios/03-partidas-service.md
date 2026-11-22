# partidas-service

## Responsabilidad

Gestiona partidas clásicas, contrarreloj y versus, historial, ranking y cierre por saga.

## Arquitectura

| Capa | Contenido |
|---|---|
| Domain | Match, estados y reglas |
| Application | Puertos y casos de uso |
| Infrastructure | FastAPI, Redis, clientes Eureka/HTTP y Kafka |

## Máquina de estados

| Estado | Significado |
|---|---|
| PENDIENTE | Partida finalizada y esperando registro de perfil |
| CONFIRMADA | Usuarios confirmó el registro |
| ANULADA | El resultado fue cancelado por compensación |

## Redis

Se usan claves para partidas, progreso versus, ranking, historial y outbox de eventos. El reconciliador recupera eventos pendientes y reemite `MatchFinished`.

## Endpoints

| Método | Ruta | Uso |
|---|---|---|
| POST | `/matches/classic` | Crear partida clásica |
| POST | `/matches/classic/{matchId}/attempts` | Enviar intento |
| POST | `/matches/timed` | Crear contrarreloj |
| POST | `/matches/timed/{matchId}/finish` | Finalizar contrarreloj |
| POST | `/matches/versus` | Crear sala |
| POST | `/matches/versus/{matchId}/join` | Unirse |
| PUT | `/matches/versus/{matchId}/progress` | Reportar progreso |
| GET | `/matches/versus/{matchId}/progress` | Consultar progreso |
| POST | `/matches/versus/{matchId}/submit` | Enviar solución |
| GET | `/matches/ranking` | Ranking |
| GET | `/matches/history/me` | Historial del usuario |
| GET | `/matches/{matchId}/saga` | Estado de la saga |
| GET | `/health` | Salud Redis |
| GET | `/metrics` | Métricas protegidas |

## Identidad

El `userId` proviene exclusivamente de `X-User-Id` validado por el Gateway. Los endpoints GET no reciben identidad por body.
