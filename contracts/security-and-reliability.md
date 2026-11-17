# Contrato de seguridad y confiabilidad v1

Este documento define los acuerdos entre Gateway, usuarios-service,
casos-service, partidas-service y el cliente. El esquema de error está en
`error.v1.schema.json`.

## Identidad y permisos

El Gateway valida el token y elimina los encabezados de identidad recibidos del
cliente antes de escribir `X-User-Id`, `X-Roles` y `X-Gateway-Secret`. Los
servicios solo confían en esos encabezados dentro de la red y cuando la
credencial interna configurada es válida. El cliente nunca envía encabezados de
identidad ni secretos internos.

| Operación | USER | ADMIN | Servicio interno |
|---|---:|---:|---:|
| Consultar y validar casos publicados | Sí | Sí | Sí, con secreto del Gateway |
| Crear, editar o borrar casos | No | Sí | No |
| Leer o cambiar el perfil propio, estadísticas y logros | Sí | Sí | No |
| Crear y jugar partidas propias | Sí | Sí | No |
| Leer progresión y registrar resultados de usuarios | No | No | Sí, con `X-Internal-Token` |
| `GET /health` y documentación pública configurada | Sí, sin identidad | Sí, sin identidad | Sí |

Las rutas de validación de casos y de registro de resultados son internas; el
Gateway las bloquea cuando se solicitan desde fuera, incluso con un Bearer
token. Las rutas administrativas de casos además requieren rol ADMIN. Los
servicios internos no deben interpretar `X-Roles` enviado directamente por un
cliente como una autorización válida.

## Errores HTTP

Toda respuesta de error pública usa `application/json` y este sobre:

```json
{
  "status": 503,
  "error": "UPSTREAM_UNAVAILABLE",
  "message": "Un servicio requerido no está disponible",
  "requestId": "opcional",
  "details": { "field": "opcional" }
}
```

`status` coincide con el estado HTTP. `error` es un código estable en
MAYUSCULAS_CON_GUION_BAJO; `message` es breve y apto para cliente. `requestId`
se incluye cuando el Gateway lo haya asignado. `details` solo incluye errores
de validación que puedan mostrarse al usuario. Nunca se devuelven tokens,
secretos, trazas, datos de solución privada ni mensajes crudos de proveedores.

| HTTP | Código recomendado | Uso |
|---:|---|---|
| 400 | `BAD_REQUEST` | Estado de dominio inválido o solicitud no procesable |
| 401 | `UNAUTHENTICATED` | Token ausente, inválido o vencido |
| 403 | `FORBIDDEN` | Rol insuficiente o ruta interna solicitada externamente |
| 404 | `NOT_FOUND` | Recurso o caso inexistente |
| 409 | `CONFLICT` | Duplicado idempotente incompatible o recurso ocupado |
| 422 | `VALIDATION_ERROR` | DTO mal formado, duplicados o reglas de entrada |
| 502 | `UPSTREAM_ERROR` | Respuesta inválida o fallo de integración no atribuible a indisponibilidad |
| 503 | `UPSTREAM_UNAVAILABLE` | Servicio requerido temporalmente no disponible |

## Reintentos, duplicados e idempotencia

- Reintentar GET solo ante errores transitorios de conexión, 502, 503 o 504,
  con máximo de 2 reintentos, backoff exponencial con jitter y presupuesto total
  acotado. No reintentar 4xx.
- Una operación de escritura solo se reintenta automáticamente si lleva una
  clave estable de idempotencia y el servidor guarda/reproduce el resultado. En
  CLASSIC, `attemptId` identifica el intento y el servidor rechaza la misma
  clave con posiciones distintas. Para TIMED/VERSUS, una respuesta perdida
  requiere consultar el estado antes de repetir el envío; no repetir a ciegas.
- El registro de resultados de usuario usa `matchId` como identidad idempotente.
  El mismo resultado se reproduce; un resultado contradictorio se rechaza con
  conflicto.
- Validar una solución repetida no implica aplicar dos veces el resultado ni
  volver a cerrar una partida. Las transiciones de estado del partido son la
  autoridad para aceptar un único cierre.

## Kafka y DLQ

La DLQ se usa solo para consumidores de eventos asíncronos: después de agotar
reintentos limitados para un evento inválido o no procesable, el consumidor
publica el evento original junto con el error/correlation id en la DLQ y
confirma el offset únicamente después de publicar con éxito. Eventos transitorios
se reintentan antes de ir a DLQ. El consumidor deduplica por `eventId` para
evitar aplicar un evento más de una vez.

El Kafka actual es una prueba de concepto de `poc.ping` y su DLQ; los flujos de
partidas y progresión son HTTP síncronos. No se debe reportar una DLQ de negocio
activa hasta que haya consumidores de negocio conectados y probados.

## Estado de implementación

El Gateway, usuarios-service, casos-service y partidas-service emiten el sobre
`status/error/message`; solicitudes inválidas usan HTTP 422 y `details.errors`.
Los errores inesperados y de dependencias usan mensajes seguros sin trazas ni
respuestas crudas de proveedores. `requestId` se propaga cuando llega en
`X-Request-Id` y cumple el formato permitido.
