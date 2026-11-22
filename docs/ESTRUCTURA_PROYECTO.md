# Estructura del proyecto

| Módulo | Responsabilidad | Capas observadas |
|---|---|---|
| apigateway | Enrutamiento, JWT Keycloak y cabeceras confiables | configuración, filtros, rutas y seguridad |
| users_service | Cuenta, perfil, estadísticas y eventos | controladores, aplicación/servicios, persistencia JPA y Kafka |
| cases-service | Catálogo, contenido, administración y validación | src/cases/domain, application, infrastructure, http |
| partidas-service | Partidas CLASSIC, TIMED, VERSUS y saga | app/domain, application, infrastructure/adapters, routers y repositorios |
| eureka-server | Descubrimiento de servicios | aplicación Spring Boot |
| death-doku | Cliente Godot: menú, casos, tablero, tutorial y perfil | scenes, autoload, core, data, translations, tests |
| infra | PostgreSQL, MongoDB, Redis, Kafka, Keycloak, Prometheus y Grafana | Compose, configuración y dashboards |

El dominio debería depender únicamente de reglas/modelos y puertos. Los adaptadores REST, persistencia, mensajería y clientes externos se mantienen en infraestructura. Hay capas hexagonales, pero todavía no están protegidas por ArchUnit en todos los servicios y quedan componentes legacy. La auditoría detalla qué está probado.

El cliente centraliza llamadas HTTP en autoload/APIService.gd. Sus regresiones se encuentran en death-doku/tests y se ejecutan mediante tests/run_all.ps1.
