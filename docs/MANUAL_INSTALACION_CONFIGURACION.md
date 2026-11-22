# Manual de instalación local

## Requisitos

- Windows 10/11 y Docker Desktop con Compose v2.
- Godot 4.7.2 para ejecutar el cliente.
- JDK 21, Node.js 22 y npm para builds locales de servicios.
- Git si se clona el proyecto.

## Preparación y arranque

1. Clona el repositorio manteniendo todas sus carpetas anidadas.
2. Copia .env.example a .env y completa solo valores locales de desarrollo. No uses secretos reales ni subas el archivo.
3. Desde la raíz ejecuta docker compose config --quiet para comprobar configuración.
4. Ejecuta docker compose up --build -d y espera healthchecks.
5. Abre death-doku/project.godot con Godot 4.7.2.
6. En primer acceso, inicia el flujo OIDC y configura TOTP con una app autenticadora.

## Puertos locales

| Servicio | URL |
|---|---|
| Gateway | http://localhost:8765 |
| Keycloak | http://localhost:8180 |
| Eureka | http://localhost:8762 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |

Prometheus y Grafana no tienen healthcheck en el Compose actual. Swagger no está agregado todavía en el Gateway; revisa el OpenAPI de cada servicio.

## Pruebas

Para comandos por servicio y evidencia de regresión, consulta README.md y docs/AUDITORIA_INICIAL.md. El runner de usuarios usa PostgreSQL temporal. Los runners H04-03/04/05 crean su propia infraestructura de prueba y limpian solo recursos etiquetados por su ejecución.

## Detener

Desde la raíz: docker compose down. No agregues -v salvo que decidas expresamente borrar datos locales persistidos.

## Limitaciones conocidas

El cliente Godot no está dentro del Compose. La configuración de TOTP requiere interacción humana; no se distribuyen códigos temporales ni contraseñas. Revisa docs/PLAN.md para las tareas de cierre.
