# Arquitectura general

## Visión

DeathDoku usa servicios independientes con separación hexagonal/DDD, integración mediante API REST y mensajería por eventos. Eureka permite descubrimiento interno; el API Gateway valida identidades; Prometheus y Grafana observan salud y actividad.

## Diagrama

```text
Godot
  |
  v
API Gateway 8765
  +-- Eureka 8762
  +-- Keycloak 8180
  |
  +--> casos-service 8082 --> MongoDB
  +--> usuarios-service 8081 --> PostgreSQL
  +--> partidas-service 8000 --> Redis
                         |
                         v
                   Kafka / tópicos / DLQ
                         |
                         v
              Prometheus --> Grafana
```

## Capas hexagonales

1. **Dominio:** entidades, value objects y reglas puras.
2. **Aplicación:** casos de uso y puertos de entrada/salida.
3. **Infraestructura:** REST, persistencia, Eureka, mensajería y observabilidad.

Las implementaciones concretas deben depender de puertos; los controladores no contienen decisiones de negocio.

## EDA y SAGA

El cierre de partida publica un evento durable. Usuarios procesa la actualización de forma idempotente y produce el resultado confirmado o cancelado. Partidas consume la respuesta y aplica confirmación o compensación. El estado PENDIENTE permite reconciliación.

## Seguridad

Keycloak emite JWT mediante Device Authorization Grant. El Gateway rechaza clientes sin JWT válido, elimina cabeceras de identidad suministradas por el cliente y las reconstruye desde claims validados.

## Decisiones arquitectónicas

| ADR | Decisión | Motivo |
|---|---|---|
| ADR-01 | Eureka por dentro | Descubrimiento sin direcciones quemadas |
| ADR-02 | Gateway único externo | Saneamiento de identidad y JWT |
| ADR-03 | Redis de partidas | Estado rápido y outbox durable |
| ADR-04 | Outbox e idempotencia | Evitar duplicados en la saga |
| ADR-05 | Kafka en despliegue actual | El repositorio implementa Apache Kafka para tópicos y DLQ |

Nota: la rúbrica pide RabbitMQ, pero la implementación desplegada usa Kafka. Sustituir el broker requiere migrar productores, consumidores, DLQ y scripts sin cambiar contratos JSON.
