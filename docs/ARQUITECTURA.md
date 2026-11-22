# Arquitectura

## Vista de contexto

Jugador/Admin → Cliente Godot → API Gateway → users_service, cases-service y partidas-service. Keycloak autentica al cliente y el Gateway valida JWT. Eureka descubre servicios. users_service usa PostgreSQL; cases-service usa MongoDB; partidas-service guarda estado en Redis. Kafka enlaza eventos entre partidas y usuarios. Prometheus recolecta métricas y Grafana las presenta.

## Patrones

- Hexagonal y DDD: capas de dominio, aplicación e infraestructura presentes con cobertura desigual. ArchUnit aún no protege todos los límites.
- EDA: Kafka, consumidores, outbox y pruebas aisladas de DLQ/reentrega existen. Falta demostrar un contrato de evento homogéneo, versionado y la integración completa entre servicios.
- CQRS: separación parcial de consultas/progreso; ranking y progreso versus como read models aún no están completos.
- Saga: hay flujo de estados/eventos al cerrar partidas; la compensación y la idempotencia deben demostrarse con escenario de fallo extremo a extremo.

## Secuencia objetivo de resolución

1. Cliente envía solución al servicio de partidas.
2. Partidas solicita validación al servicio de casos.
3. Casos devuelve el resultado de la validación autoritativa.
4. Partidas publica MatchFinished/CaseSolved con correlationId.
5. Usuarios consume el evento idempotentemente, registra resultado, XP y evalúa logros.
6. Si falla la persistencia, la saga registra estado recuperable/compensación.

Este flujo resume el objetivo; no afirma que compensaciones y E2E estén cerrados. Véase docs/AUDITORIA_INICIAL.md.
