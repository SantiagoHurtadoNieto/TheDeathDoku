# casos-service

## Responsabilidad

Administra el catálogo de casos, metadatos visuales, reglas y validación de soluciones. Usa NestJS, MongoDB y Eureka.

## Estructura lógica

| Carpeta | Capa |
|---|---|
| `src/cases/domain` | Entidades y reglas de casos |
| `src/cases/application` | Casos de uso y puertos |
| `src/cases/infrastructure` | MongoDB, REST y DTO |
| `src/eureka` | Registro y descubrimiento |
| `src/observability` | Métricas, salud y autenticación |

## Persistencia

Colección MongoDB recomendada: `cases`. Los documentos incluyen identificadores, título, categoría, dificultad, tablero, personajes, objetos, solución y pistas.

## Endpoints principales

| Método | Ruta | Headers | Respuesta |
|---|---|---|---|
| GET | `/health` | Ninguno | Estado UP |
| GET | `/cases` | Bearer, X-User-Id inyectado | Lista paginada o completa |
| GET | `/cases/:id` | Bearer | Detalle |
| POST | `/cases/:id/validate` | Bearer | Resultado de validación |
| GET | `/metrics` | Basic metrics | Métricas Prometheus |
| GET | `/docs` | Ninguno | Swagger UI |

Las rutas administrativas deben exigir rol ADMIN. El detalle exacto se toma de la especificación Swagger publicada por el servicio.

## Variables

| Variable | Uso |
|---|---|
| PORT | Puerto HTTP |
| MONGO_URI | Conexión MongoDB |
| EUREKA_HOST / EUREKA_PORT | Registro Eureka |
| GATEWAY_SECRET | Confianza del Gateway |
| METRICS_SCRAPE_PASSWORD_FILE | Credencial Prometheus |
| KAFKA_BOOTSTRAP_SERVERS | Broker de mensajería |
