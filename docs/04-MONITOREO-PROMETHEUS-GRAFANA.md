# Monitoreo con Prometheus y Grafana

## Arquitectura

Prometheus consulta los endpoints `/metrics`, `/prometheus` o `/actuator/prometheus` cada 15 segundos. Grafana usa Prometheus como datasource y carga dashboards provisionados.

## Métricas

| Métrica | Tipo | Servicio |
|---|---|---|
| `http_requests_total` | Counter | Todos |
| `http_server_requests_seconds` / `http_request_duration_seconds` | Histogram | Todos |
| `matches_finished_total` | Counter | partidas-service |
| `events_processed_total` | Counter | Usuarios y partidas |
| `sagas_pending` | Gauge | partidas-service |

La métrica de usuarios puede incluir métricas Micrometer con prefijos equivalentes.

## Scrape

| Job | Target |
|---|---|
| api-gateway | `api-gateway:8766` |
| eureka-server | `eureka-server:8763` |
| cases-service | `casos-service:8082/metrics` |
| usuarios-service | `usuarios-service:8081/prometheus` |
| partidas-service | `partidas-service:8000/metrics` |

Todos los scrapes de aplicaciones usan Basic Auth configurable con secretos.

## Dashboard

El dashboard incluye:

1. Estado de targets con `up`.
2. Disponibilidad por servicio.
3. Duración y volumen HTTP.
4. Estados del negocio y sagas pendientes.
5. Errores y colas de eventos.

## Alerta

`DeathDokuServiceDown` se activa cuando `up == 0` durante un minuto para Gateway, Eureka, casos, usuarios o partidas.
