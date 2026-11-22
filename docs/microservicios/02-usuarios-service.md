# usuarios-service

## Responsabilidad

Administra perfil, experiencia, progreso, logros y registro interno de resultados.

## Arquitectura

| Capa | Implementación |
|---|---|
| Domain | `Player`, `Achievement`, `Experience`, políticas |
| Application | Casos de uso y puertos |
| Infrastructure | JPA, REST, eventos Kafka, Eureka |

## Modelo JPA

Entidades principales:

| Entidad | Datos |
|---|---|
| `Player` | subject Keycloak, nombre, avatar, idioma, tutorial |
| `Experience` | XP actual y nivel |
| `Achievement` | identificador y estado desbloqueado |
| `ProcessedEvent` | eventId idempotente |
| `MatchSagaOutbox` | respuesta pendiente de publicación |

## Endpoints

| Método | Ruta | Acceso |
|---|---|---|
| GET | `/health` | Público |
| GET | `/swagger-ui/**` | Público |
| GET | `/users/me` | Usuario autenticado |
| PUT | `/users/me` | Usuario autenticado |
| PATCH | `/users/me/language` | Usuario autenticado |
| PUT | `/users/me/tutorial` | Usuario autenticado |
| GET | `/users/me/stats` | Usuario autenticado |
| GET | `/users/me/achievements` | Usuario autenticado |
| POST | `/users/{id}/results` | Servicio interno |
| GET | `/users/{id}/progression` | Servicio interno |
| GET | `/users/{id}/solved-cases` | Servicio interno |

El endpoint `/users/{id}/results` no debe ser enrutable desde el Gateway. Usa `X-Internal-Token` o identidad de servicio.

## Consumo idempotente

Cada `MatchFinished` se valida y se busca por `eventId`. La actualización usa una transacción y publica por outbox una confirmación o cancelación. Los logs incluyen `eventId`, `correlationId` y `matchId`.
