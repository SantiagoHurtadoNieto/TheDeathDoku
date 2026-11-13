# Observability local (P7-A/P7-B)

Prometheus recolecta metricas de `api-gateway`, `eureka-server`,
`cases-service`, `usuarios-service` y `partidas-service`. No recoge todavia
metricas de Keycloak o Kafka.

## Seguridad y puertos

- Prometheus (`9090`) y Grafana (`3000`) solo publican puertos en
  `docker-compose.dev.yml`, enlazados a `127.0.0.1`.
- Gateway y Eureka conservan sus puertos de aplicacion (`8765` y `8762`) y
  Actuator usa listeners internos separados (`8766` y `8763`). `usuarios-service`
  conserva `/health` y sirve sus metricas protegidas en `/prometheus` sobre su
  puerto interno `8081`. Ninguno de esos puertos de gestion se publica en host.
- `cases-service` expone `/metrics` en su puerto interno `8082`; el endpoint
  exige Basic Auth. El puerto solo se publica en loopback en el override de
  desarrollo. Las rutas `/casos/**` del Gateway requieren Bearer y el guard de
  metricas exige Basic, por lo que el Gateway no puede consultar este endpoint.
- `usuarios-service` conserva su puerto de aplicacion `8081` y el health check
  `/health`. Expone Prometheus en `/prometheus`, dado que su base-path actual
  de Actuator es `/`. La ruta requiere Basic en una cadena exclusiva de
  seguridad para metricas; el filtro de identidad del Gateway no la procesa.
  El servicio no publica puertos en el host.
- El endpoint Prometheus requiere HTTP Basic Auth con el usuario fijo `metrics`
  y una contrasena local ignorada por Git; Prometheus recibe la misma contrasena
  desde el secreto local `metrics_scrape_password`.
- Los targets se scrapean directamente, no a traves del Gateway. Los listeners
  Java de gestion no se publican en el host.
- Solo se exponen `health` y `prometheus` en esos listeners. No se exponen
  `env`, `configprops`, `heapdump`, `loggers` ni otros endpoints de Actuator.
- `cases-service` registra el histograma `http_server_requests_seconds` con
  etiquetas `application`, metodo HTTP permitido, plantilla de ruta y estado
  HTTP. Su serie `_count` indica solicitudes y `_sum`/`_bucket` describen la
  duracion. No se etiqueta con valores de peticion; las plantillas de ruta
  conservan `:id` y Prometheus descarta `uri` antes de almacenarlas.
- `usuarios-service` registra solicitudes y duracion con
  `http_server_requests_seconds_count` y `_sum`, usando etiquetas de
  aplicacion, metodo, plantilla de ruta y estado. Prometheus descarta `uri` y
  `exception`, sin etiquetas de identidad ni datos de usuario.
- `partidas-service` registra el histograma `http_server_requests_seconds` con
  etiquetas `application`, metodo HTTP normalizado, plantilla de ruta y estado.
  El endpoint `GET /metrics` usa Basic Auth y queda excluido de las propias
  metricas; la contrasena llega mediante `METRICS_SCRAPE_PASSWORD` local y
  Prometheus usa el secreto `metrics_scrape_password` existente.
- Prometheus descarta las etiquetas `uri` y `exception` antes de almacenar las
  muestras. La configuracion no crea etiquetas de usuario, caso, partida o
  token.
- Grafana requiere credenciales locales. Define `GRAFANA_ADMIN_USER` y
  `GRAFANA_ADMIN_PASSWORD` en el archivo `.env` ignorado por Git. No uses los
  valores de ejemplo sin reemplazarlos.

La red interna de Compose es compartida por los servicios del stack. La
autenticacion Basic protege las metricas tambien frente a solicitudes directas
desde otros contenedores. Los endpoints de salud siguen separados y no contienen
detalles.

## Arranque en Windows

Desde `C:\dev\TheDeathDoku`, añade credenciales propias al `.env` ignorado y
crea `./.secrets/metrics_scrape_password` con exactamente el mismo valor de
`METRICS_SCRAPE_PASSWORD`. No guardes ese valor en este repositorio. Luego
ejecuta:

```powershell
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.stable.local.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.stable.local.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.stable.local.yml ps
```

Abre Prometheus en `http://127.0.0.1:9090` y Grafana en
`http://127.0.0.1:3000`. En Grafana, el datasource Prometheus y el dashboard
`DeathDoku - Observability` se aprovisionan automáticamente.

## Comprobaciones

```powershell
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec api-gateway wget -qO- http://127.0.0.1:8766/actuator/health
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec eureka-server wget -qO- http://127.0.0.1:8763/actuator/health
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.stable.local.yml exec usuarios-service curl -fsS http://127.0.0.1:8081/health
Invoke-WebRequest http://127.0.0.1:8081/prometheus -SkipHttpErrorCheck | Select-Object -ExpandProperty StatusCode
$scrapeCredential = Get-Credential -UserName metrics -Message 'Local Prometheus scrape credential'
$metricsResponse = Invoke-WebRequest http://127.0.0.1:8081/prometheus -Authentication Basic -Credential $scrapeCredential
$metricsResponse.Content.Contains('http_server_requests_seconds')
Invoke-RestMethod http://127.0.0.1:9090/api/v1/targets | ConvertTo-Json -Depth 8
Invoke-WebRequest http://127.0.0.1:8765/actuator/prometheus -SkipHttpErrorCheck | Select-Object -ExpandProperty StatusCode
Invoke-WebRequest http://127.0.0.1:8082/metrics -SkipHttpErrorCheck | Select-Object -ExpandProperty StatusCode
```

Los endpoints de health deben responder `UP`. La solicitud publica al path de
metricas del Gateway debe devolver error HTTP, incluso al repetirla con Bearer
valido. Una solicitud autenticada al Gateway para
`/usuarios/prometheus` tambien debe ser rechazada; el servicio corta las
peticiones que llevan el encabezado interno del Gateway. La solicitud directa
a `/metrics` sin Basic debe responder `401`;
`cases-service` y `usuarios-service` deben quedar `UP` en Prometheus, lo que
confirma su scraping autenticado. La primera solicitud a `/prometheus` debe
devolver `401`; la solicitud con la credencial solicitada interactivamente
debe contener `http_server_requests_seconds`. Comprueba tambien que `/health`
sigue accesible. Los targets esperados son `prometheus`,
`api-gateway`, `eureka-server`, `cases-service` y `usuarios-service`. En
Grafana confirma que el datasource esta `OK` y que los paneles incluyen los
datos de los cuatro servicios despues de generar solicitudes HTTP.

Para validar los cambios Java sin contenedores, ejecuta `mvn test` desde
`apigateway` y `eureka-server`. Para probar scrapes, healthchecks, targets,
dashboard y Bruno se necesita Docker Desktop con el daemon disponible y el
stack de desarrollo completo. Ejecuta la regresion desde `regression` con
`npx --yes @usebruno/cli@4.3.0 run --env local`.
