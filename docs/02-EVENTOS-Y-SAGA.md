# Eventos y SAGA

## Catálogo

| Evento | Productor | Consumidor | Estado |
|---|---|---|---|
| `MatchFinished` | partidas-service | usuarios-service | PENDIENTE |
| `ResultRecorded` | usuarios-service | partidas-service | CONFIRMADA |
| `ResultRecordingFailed` | usuarios-service | partidas-service | ANULADA |

La implementación actual usa tópicos Kafka con nombres equivalentes a estos eventos; el catálogo lógico conserva los contratos de la rúbrica.

## MatchFinished

```json
{
  "eventId": "UUID",
  "correlationId": "saga-123",
  "occurredAt": "2026-11-22T12:00:00Z",
  "payload": {
    "matchId": "match-123",
    "caseId": "case-123",
    "mode": "CLASSIC",
    "timeSeconds": 120,
    "results": [
      {
        "userId": "UUID",
        "won": true,
        "xpDelta": 50,
        "difficulty": "MEDIUM"
      }
    ]
  }
}
```

## Resultado confirmado

```json
{
  "eventId": "UUID",
  "correlationId": "saga-123",
  "occurredAt": "2026-11-22T12:00:01Z",
  "payload": {
    "matchId": "match-123",
    "status": "CONFIRMADA",
    "newExperience": 1250,
    "newAchievements": ["FIRST_WIN"]
  }
}
```

## Resultado fallido

```json
{
  "eventId": "UUID",
  "correlationId": "saga-123",
  "occurredAt": "2026-11-22T12:00:01Z",
  "payload": {
    "matchId": "match-123",
    "status": "ANULADA",
    "reason": "No fue posible registrar XP"
  }
}
```

## Flujo feliz

1. Partidas valida la solución contra casos-service.
2. Cambia o mantiene la partida en PENDIENTE.
3. Guarda `MatchFinished` en Redis outbox.
4. El productor publica el evento.
5. Usuarios verifica `eventId` y aplica XP/logros.
6. Usuarios publica la respuesta.
7. Partidas cambia el estado a CONFIRMADA.

## Flujo de compensación

1. Usuarios intenta registrar XP.
2. Si ocurre un error definitivo, publica o deriva el estado cancelado.
3. El consumidor DLQ también puede crear una compensación correlacionada.
4. Partidas cambia PENDIENTE a ANULADA.
5. El reconciliador evita reprocesar eventos terminales.

## Idempotencia

Usuarios persiste eventos procesados por `eventId`. Repetir el mismo evento no suma XP otra vez. Partidas usa claves y estado para evitar doble transición terminal.

## Trazabilidad

Todos los logs de la saga deben mostrar `eventId`, `correlationId` y `matchId`. La métrica técnica usa `correlationId` solo en logs, nunca como etiqueta de cardinalidad alta.

## DLQ

Los eventos inválidos o que agotan reintentos se conservan en un tópico DLQ. No deben perderse ni bloquear indefinidamente al consumidor.
