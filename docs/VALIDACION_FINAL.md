# Validación final — estado del corte

**Fecha:** 22 de noviembre de 2026. Este informe no equivale a certificación completa: quedan requisitos funcionales abiertos.

## Resultados ejecutados

| Área | Resultado | Evidencia |
|---|---|---|
| Compose | Configuración/builds correctos; casos-service reconstruido y healthy. Seed informó 30 casos sincronizados y 0 pruebas antiguas retiradas. | docker compose y log del SeedService |
| Gateway | 24 pruebas, 0 fallos. | Maven Surefire |
| Eureka | 1 prueba, 0 fallos. | Maven Surefire |
| Usuarios | 129 pruebas, 0 fallos, 2 saltadas con runner PostgreSQL aislado, incluida prueba del seed de 11 logros y baseline legado. | users_service/tests/run_postgres_migrations.ps1 |
| Outbox y logros de usuarios | Compose arrancó healthy; Flyway conservó el esquema existente, creó baseline V3 y aplicó V4; la tabla existe (0 pendientes). La BD tiene 11 logros únicos. No se observaron errores SQL del outbox tras el reinicio. | logs de `usuarios-service`, PostgreSQL de Compose y prueba aislada de baseline legado |
| Casos | Build correcto; 43 pruebas, 0 fallos; 30 seeds, categorías y dimensiones validadas. El solver confirma exactamente una distribución espacial válida por caso. | npm build/test |
| Partidas unitarias | 175 aprobadas; las pruebas que necesitan servicios externos se ejecutan en runners separados. | pytest en contenedor |
| Partidas H04-03 | 202 pasaron, 1 omitida, 0 fallos; incluye publicación de progreso y WebSocket. | runner Redis aislado corregido |
| Partidas H04-04 y H04-05 | Runners aislados terminan con código 0 y limpian sus recursos temporales. | runners Kafka/Redis |
| Cliente Godot | Import y 11 scripts pasan; RUNNER OK. | tests/run_all.ps1 |
| Vulnerabilidades npm | Sin reporte por DNS: registry.npmjs.org no resolvió. No afirmar cero CVE. | intento npm audit |

## Puerta de calidad pendiente

- No se probó un clon limpio ni un recorrido de todas las HU con usuario real.
- MFA requiere enrolar TOTP manualmente y repetir el flujo autenticado completo.
- No se ejecutaron ArchUnit, E2E completos entre servicios ni reporte de cobertura ≥70%.
- El solver demuestra unicidad de la distribución espacial (personajes, filas, columnas y habitaciones) en los 30 casos, y rechaza soluciones ambiguas o pistas no soportadas. El modelo actual de pistas no permite deducir unicidad de la identidad del culpable; `killerId` sigue siendo parte de la respuesta privada del caso.
- Versus publica progreso al canal Redis y lo transmite por WebSocket autenticado a través del Gateway; el cliente Godot reconecta y conserva consulta periódica como respaldo. La prueba del endpoint y las suites pasan, pero falta una demostración E2E en vivo con Gateway, dos clientes autenticados y partida real.
- OpenAPI no está agregado en el Gateway; versionado y RFC 7807 deben cerrarse.
- No hay auditoría Lighthouse/axe aplicable al cliente Godot ni prueba integral de exportación Windows.
- No se comprobó que Prometheus y Grafana reporten paneles de negocio/alertas para cada servicio.
- El baseline de Flyway asume que un esquema sin historial corresponde al diseño previo a V4; el cambio aplica una migración aditiva V4 y mantiene `clean` desactivado. Se verificó en esquema PostgreSQL aislado con datos preservados.
- El paquete final no se generó para evitar dar por cerrada una versión que aún no supera la puerta funcional.

Las cifras de pruebas anteriores se mantienen donde no se volvieron a ejecutar durante esta tarea. La regresión final de Godot se ejecutó con 11 scripts y terminó en `RUNNER OK`.

El cambio del menú y el selector de idioma no afecta autenticación ni modifica opciones de juego. Las dos verificaciones de Godot que fallaban ahora pasan.
