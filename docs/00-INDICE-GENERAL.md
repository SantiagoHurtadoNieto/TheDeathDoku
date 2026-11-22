# HopeDoku / DeathDoku

## Portada

**Proyecto:** HopeDoku / DeathDoku  
**Curso:** Ingeniería de Software II  
**Corte:** Reto Segundo Corte  
**Alcance:** cliente Godot 4.7, cuatro servicios distribuidos, seguridad OAuth2/MFA y observabilidad.

## Resumen ejecutivo

El proyecto combina un juego de deducción con arquitectura distribuida. El catálogo de casos usa NestJS y MongoDB, los perfiles usan Spring Boot y PostgreSQL, las partidas usan Python/FastAPI y Redis, y el acceso externo pasa por un API Gateway con Eureka. La entrega incluye saga por mensajería, idempotencia, compensación, métricas, alertas y documentación.

## Integrantes y roles

| Integrante | Rol sugerido |
|---|---|
| Equipo de desarrollo | Arquitectura, backend, infraestructura y despliegue |
| Equipo QA | Pruebas unitarias, integración, regresión y sustentación |
| Equipo UI/UX | Diseño Godot, accesibilidad, usabilidad e idioma |

La asignación final debe completarse con los nombres reales del curso.

## Stack tecnológico

| Área | Tecnología |
|---|---|
| Frontend | Godot Engine 4.7, GDScript |
| Gateway | Spring Cloud Gateway |
| Discovery | Netflix Eureka |
| Identidad | Keycloak OAuth2/OpenID Connect, TOTP |
| Casos | NestJS, TypeScript, MongoDB |
| Usuarios | Java, Spring Boot, JPA, PostgreSQL |
| Partidas | Python, FastAPI, Redis |
| Mensajería | Apache Kafka sobre tópicos y DLQ; diseño compatible con escenarios de saga |
| Observabilidad | Prometheus y Grafana |
| Contenedores | Docker Compose |

## Navegación

| Documento | Contenido |
|---|---|
| [Arquitectura general](./01-ARQUITECTURA-GENERAL.md) | Diseños y decisiones |
| [Casos](./microservicios/01-casos-service.md) | Catálogo y validación |
| [Usuarios](./microservicios/02-usuarios-service.md) | Perfil, XP y logros |
| [Partidas](./microservicios/03-partidas-service.md) | Estados y Redis |
| [Gateway y Eureka](./microservicios/04-api-gateway-y-eureka.md) | Ruta y seguridad |
| [Eventos y saga](./02-EVENTOS-Y-SAGA.md) | Contratos y compensación |
| [Seguridad](./03-SEGURIDAD-KEYCLOAK-MFA.md) | Device grant y TOTP |
| [Monitoreo](./04-MONITOREO-PROMETHEUS-GRAFANA.md) | Métricas y alertas |
| [Instalación](./05-MANUAL-INSTALACION-Y-CONFIGURACION.md) | Máquina limpia |
| [Usuario](./06-MANUAL-DE-USUARIO.md) | Pantallas e historias |
| [UI/UX](./07-AUDITORIA-UI-UX-NIELSEN.md) | Nielsen y mejora visual |
