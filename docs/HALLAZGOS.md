# Hallazgos

| ID | Severidad | Causa/evidencia | Archivos | Estado |
|---|---|---|---|---|
| DD-001 | P1 | El menú carecía de acceso compacto al idioma; una prueba omitía Opciones. | death-doku/scenes/main_menu/main_menu.gd; tests/verify_main_menu.gd | Corregido; regresión completa verde. |
| DD-002 | P2 | CaseLibrary conectaba dos veces auth_logged_out. | death-doku/scenes/cases/CaseLibrary.gd | Corregido; regresión verde. |
| DD-003 | P2 | Runner H04-03 de Redis ejecutaba una prueba exclusiva de Kafka. | partidas-service/tests/h04-03 | Corregido; 202 pasaron, 1 omitida, 0 fallos. |
| DD-004 | P1 | La validación comparaba con respuesta privada, pero no demostraba unicidad desde restricciones/pistas. | cases-service/src/cases/domain | Corregido para la distribución espacial: solver verifica una solución única en los 30 casos y rechaza casos ambiguos o sintaxis de pistas no soportada; 43 pruebas verdes. El modelo de pistas no puede deducir la identidad del culpable, que sigue siendo respuesta privada. |
| DD-005 | P1 | Keycloak exige TOTP pero no se verificó enrolamiento con app autenticadora. | infra/keycloak | Abierto; requiere enrolamiento y E2E. |
| DD-006 | P2 | No había canal en tiempo real para progreso versus. | partidas-service/app/routers/matches.py; apigateway; death-doku/autoload/APIService.gd | Corregido: Redis Pub/Sub a WebSocket autenticado por Gateway, snapshot inicial, eventos y reconexión; cliente mantiene sondeo de respaldo. 202 pruebas Partidas y 11 scripts Godot verdes. Falta E2E en vivo con Gateway y dos clientes autenticados. |
| DD-007 | P2 | El catálogo requiere al menos diez logros y evaluación por evento; la vitrina bloqueada/progreso aún está pendiente. | users_service; Godot | Parcial: catálogo de 11, evaluación en consumidor MatchFinished, 128 pruebas verdes; UI pendiente. |
| DD-008 | P2 | Hace falta evidencia de compensación/idempotencia de saga de extremo a extremo. | partidas-service y users_service | Parcial; runners aislados pasan. |
| DD-009 | P2 | npm audit no resuelve registry.npmjs.org por limitación DNS/red. | cases-service | Bloqueado; reintentar con conectividad. |
| DD-010 | P1 | Soluciones permitían personajes en la misma fila o columna. | cases-service/src/cases/domain/case-definition.policy.ts | Corregido con validación de dominio; 30 seeds y 41 pruebas pasan. |
| DD-011 | P2 | Seed tenía categorías requeridas insuficientes y no incluía tablero 9x9. | cases-service/src/cases/seed/catalog.json | Corregido: 30 seeds, 3 por categoría requerida y tamaños 6, 8 y 9; suite 41/41. |
| DD-012 | P1 | Flyway estaba deshabilitado en el arranque normal; `match_saga_outbox` no existía y el publicador fallaba con errores SQL recurrentes. | users_service/src/main/resources/application.properties; migration tests | Corregido: baseline seguro en V3 para esquema existente, aplicación aditiva de V4, `clean` desactivado; 129 pruebas pasan y Compose healthy. |

No se incluyeron credenciales, tokens ni códigos TOTP en esta documentación.
