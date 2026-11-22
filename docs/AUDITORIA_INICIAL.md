# Auditoría inicial de DeathDoku

**Fecha:** 22 de noviembre de 2026  
**Alcance:** segundo corte, requisitos de `PROMPT_CODEX_DeathDoku.md`, repositorios actuales y pruebas ejecutables en este entorno.  
**Commits:** no se crean; el usuario los realizará manualmente.

## Resumen ejecutivo

El proyecto ya tiene una base funcional distribuida: cliente Godot, API Gateway, usuarios, casos, partidas y Eureka; además de Keycloak, Kafka, PostgreSQL, MongoDB, Redis, Prometheus y Grafana en Compose. Los servicios Java compilan y sus suites pasan. Casos pasa 39 pruebas; usuarios pasa 127 (2 saltadas); Gateway pasa 24; Eureka pasa 1. Partidas pasa 175 pruebas unitarias y sus runners aislados de Kafka pasan; una ejecución sin Kafka externo falla únicamente en la integración H04-04. El proyecto Godot importa y arranca en headless, pero la regresión completa falla en dos verificaciones del menú e idioma. No se debe considerar el entregable completo todavía.

La cobertura del producto es desigual. Hay autenticación Keycloak con JWT, roles y requisito de enrolamiento TOTP, partidas/casos validados por backend y flujo de eventos para sagas. Persisten brechas respecto al solver de unicidad y a las reglas completas del tablero, progreso versus en tiempo real, la cobertura de logros, accesibilidad/i18n global, el flujo de administración con publicación segura y la documentación/automatización de entrega.

## Mapa del repositorio

| Módulo | Tecnología / responsabilidad | Evidencia y estado |
|---|---|---|
| `death-doku/` | Cliente de escritorio Godot 4.7.2; UI y consumo de APIs | Importación y ejecución headless correctas. Suite: 8 verificaciones verdes y 2 scripts fallidos (`verify_main_menu`, `verify_journal_screens`). Hay preset Web, no preset de Windows. |
| `apigateway/` | Spring Boot 4.1.1, Spring Cloud Gateway; JWT Keycloak, rutas y cabeceras confiables | 24 pruebas, 0 fallos. El OpenAPI agregado, versionado `/api/v1`, rate limit y manejo RFC 7807 deben cerrarse/verificarse. |
| `users_service/` | Spring Boot 4.1.1, Java 21, PostgreSQL/JPA, perfil/progreso y consumo/outbox Kafka | Runner de migraciones aislado: 127 pruebas, 0 fallos, 2 saltadas. La ejecución Maven directa no es válida sin sus variables/DB de prueba. Logros inicializados: 4, menos que los 10 requeridos. |
| `cases-service/` | NestJS 11, Node 22, MongoDB; catálogo, pistas, validación y administración | Build correcto; 39 pruebas, 0 fallos. Seed de 30 casos disponible. No se verificó solver de unicidad; validar posiciones contra la solución guardada no sustituye un solver que compruebe diseño y consistencia. |
| `partidas-service/` | FastAPI/Python 3.12, Redis, Kafka; partidas, modos, sagas | 175 pruebas unitarias aprobadas; H04-04/H04-05 aisladas pasan. La suite completa sin Kafka externo deja fallar H04-04. El runner H04-03 ejecuta más pruebas de las que su infraestructura levanta. No se halló WebSocket/SSE para progreso del rival. |
| `eureka-server/` | Spring Boot 4.1.1; descubrimiento | 1 prueba, sin fallos. |
| `infra/` y Compose raíz | PostgreSQL, MongoDB, Redis, Kafka, Keycloak, Prometheus, Grafana | `docker compose config --quiet` y build de imágenes pasan. En el último estado consultado los servicios principales estaban saludables; Prometheus/Grafana están en ejecución sin healthcheck. Existe contenedor Kafka UI huérfano respecto a la definición base/override. |
| `contracts/`, `regression/` | Contratos y validaciones auxiliares | Existen, pero falta una única entrada raíz que ejecute contratos, servicios, cliente y E2E de forma reproducible. |

Hay repositorios Git anidados. El estado consultado de la raíz y de los seis subrepositorios fue limpio. No se observó README en raíz, carpeta `docs/` preexistente ni workflows de CI estándar; sí hay documentación específica en `infra/` y algunos servicios. El archivo de entorno de ejemplo existe; no se inspeccionaron ni copiaron los secretos locales.

## Validaciones ejecutadas

| Validación | Resultado | Observaciones |
|---|---|---|
| Compose `config --quiet` | ✅ | Configuración compuesta válida. |
| `docker compose build --quiet` | ✅ | Gateway, Eureka, usuarios, casos y partidas construyen. |
| Casos: build + Jest | ✅ | 41/41 pruebas: 30 seeds reales, regla de fila/columna, ≥3 por cuatro categorías y tamaños 6x6, 8x8, 9x9. Requiere loopback para stub de Eureka. |
| Gateway: Maven | ✅ | 24/24. |
| Eureka: Maven | ✅ | 1/1. |
| Usuarios: runner PostgreSQL de migraciones | ✅ | Tras agregar catálogo de logros: 128 ejecutadas, 0 fallos, 2 saltadas. |
| Partidas: unitarias en contenedor | ✅ | 175/175; 26 saltadas al correr paquete completo sin servicios de integración. |
| Partidas: Kafka/Redis H04-04 y H04-05 aisladas | ✅ | Los runners terminan correctamente y limpian su infraestructura temporal. |
| Partidas: runner H04-03 | ✅ corregido | Se excluyó únicamente la integración H04-04, reservada para el runner que levanta Kafka. Nueva ejecución: 200 pasaron, 1 omitida, 0 fallos. |
| Godot import y headless | ✅ | Godot 4.7.2 importa proyecto y ejecuta headless. |
| Godot regresión | ✅ corregido | Selector compacto ES/EN agregado; botón Opciones conservado y probado; manejador duplicado retirado. Regresión completa posterior al cambio: RUNNER OK, 10 scripts. |
| Escaneo de vulnerabilidades | ⏳ bloqueado por red | `npm audit --omit=dev` se intentó; el entorno no puede resolver `registry.npmjs.org`, por lo que npm no entrega advisories. Reintentar al disponer de red. |
| MFA interactivo | ⏳ | Configuración requiere `CONFIGURE_TOTP`; el enrolamiento real requiere interacción con la app autenticadora del usuario. |

## Trazabilidad de historias de usuario

Estados: ✅ completa según evidencia disponible; 🟡 parcial; ❌ faltante; 🐞 tiene regresión demostrada. La evaluación es conservadora y no toma documentación como prueba de funcionamiento.

| HU | Implementación observada | Prueba / brecha principal | Estado |
|---|---|---|---|
| HU-01 Biblioteca | Catálogo, filtros categoría/dificultad y 30 casos; seed ahora incluye ≥3 HOGAR/OFICINAS/TRABAJO/TURISTICO y dimensiones 6x6, 8x8, 9x9 | Falta filtro de estado nuevo/en curso/resuelto, preview consistente y solver de unicidad. | 🟡 |
| HU-02 Tablero | Tablero, ocupabilidad, pistas y objetos representados | Faltan reglas de dominio completas para tamaño/zona, accesibilidad con patrón/etiqueta y validación autoritativa de todas las restricciones. | 🟡 |
| HU-03 Colocación | Colocar/mover personajes en cliente y servidor | Deshacer/rehacer y accesibilidad por teclado/táctil no están demostrados integralmente. | 🟡 |
| HU-04 Pistas | Casos exponen pistas y la UI las muestra | Aplicar/descartar y resaltar referencias en tablero no está demostrado. | 🟡 |
| HU-05 Notas | Notas locales de tablero | Persistencia de reanudación en backend no demostrada. | 🟡 |
| HU-06 Resolver | Endpoint real de casos valida posiciones contra solución persistida; partidas integra finalización | Faltan solver/única solución, asesino elegido como condición final y resumen completo verificable. | 🟡 |
| HU-07 Ayudas | Endpoint de pistas de ayuda disponible | Niveles, límite, confirmación y penalización coherente por partida no comprobados. | 🟡 |
| HU-08 Versus | Crear/unirse y casos de uso de matchmaking/lobby en partidas | Reconexion/estados y recorrido UI extremo a extremo pendientes. | 🟡 |
| HU-09 Progreso rival | Sin canal WebSocket/SSE localizado | No hay prueba de actualización del rival en tiempo real. | ❌ |
| HU-10 Resultado versus | Kafka y flujo de saga/eventos disponibles | Persistencia, desempate, abandono y XP integrado deben probarse como escenario E2E. | 🟡 |
| HU-11 Puntaje | Estadísticas/progreso y datos de partida existentes | Fórmula, historial y ranking CQRS demostrables no están cerrados. | 🟡 |
| HU-12 Contrarreloj | Modo contrarreloj en partidas/cliente | Selección de límite y reloj autoritativo no probados en E2E. | 🟡 |
| HU-13 Expiración | Lógica de cierre temporal presente | Fórmula/reducción de XP y evento de expiración deben probarse juntos. | 🟡 |
| HU-14 Bonificaciones | Resultados/XP tienen soporte parcial | Tramos y desglose de bonus al usuario no demostrados. | 🟡 |
| HU-15 Perfil | Keycloak y perfil/avatares existen | Registro/edición completa y validaciones del avatar deben comprobarse E2E. | 🟡 |
| HU-16 Progreso | Estadísticas, racha y tiempos existen parcialmente | Dashboard CQRS e historial reciente completo no demostrados. | 🟡 |
| HU-17 Logros | Inicializador cataloga ahora 11 logros; MatchFinished pasa por Kafka y el evaluador los procesa de forma idempotente por usuario | Vitrina de logros bloqueados/progreso y notificación accesible aún incompletas. | 🟡 |
| HU-18 Login seguro | Keycloak JWT, gateway, roles USER/ADMIN, refresh/logout; realm marca TOTP requerido | MFA end-to-end no se validó con enrolamiento. | 🟡 |
| HU-19 Tutorial | Tutorial visible y pruebas relacionadas | 5 pasos en tablero jugable 4×4 y persistencia del estado visto no probados. | 🟡 |
| HU-20 Idiomas | Recursos/traducciones ES/EN y selector en opciones | Selector compacto que esperan regresiones está ausente; textos y contenido de casos traducidos no están completos. | 🐞 |
| HU-21 Administración | Controlador de CRUD de casos existe | Solver de publicación, borrador/publicado, previsualización y auditoría completa no demostrados. | 🟡 |

## Requisitos del reto (sección 3 del prompt)

| Requisito | Estado | Evidencia / pendiente |
|---|---|---|
| Frontend existente | ✅ | Godot 4.7.2, decisión consistente con el proyecto. |
| ORM/DTO y no exponer entidades | 🟡 | JPA está presente en usuarios; revisar DTO/MapStruct y límites HTTP de todas las API. |
| Bus de eventos | ✅ | Kafka en Compose, consumidores y casos de DLQ/reintentos probados de forma aislada. |
| Persistencia políglota | ✅ | PostgreSQL, MongoDB y Redis operativos en infraestructura. |
| Hexagonal + DDD en cada servicio | 🟡 | Capas presentes, en especial casos/partidas/usuarios; aún quedan adaptadores/servicios legacy y límites por reforzar. |
| ArchUnit | ❌ | No se encontró dependencia ni suite ArchUnit. |
| EDA / consumidores idempotentes / DLQ | 🟡 | Saga/outbox e integraciones existen; falta verificar envelope/versionado y escenarios de entrega/reprocesamiento a través de todos los servicios. |
| CQRS | 🟡 | Hay separación parcial de consultas y eventos; read models de ranking/perfil/rival no cubren los criterios. |
| Saga y compensación | 🟡 | Flujo de saga/eventos presente; compensación y estados terminales necesitan pruebas de fallo con evidencia. |
| OAuth2/JWT, MFA y RBAC | 🟡 | JWT + roles + TOTP requerido en Keycloak; enrolamiento y autorización por rol E2E pendientes. |
| Observabilidad | 🟡 | Prometheus/Grafana incluidos; faltan healthchecks y dashboard/alertas de negocio demostrables para todos los servicios. |
| API OpenAPI agregada, RFC 7807 y `/api/v1` | 🟡 | OpenAPI local en algunos servicios; agregación/versionado/errores comunes/colección aún deben cerrarse. |
| Compose un comando y healthchecks | 🟡 | Compose y build válidos; faltan healthchecks en Prometheus/Grafana, test/seed y verificación limpia integral. |
| CI | ❌ | No se encontraron workflows CI estándar. |
| Accesibilidad, responsive, temas | 🟡 | Aplicación es escritorio Godot; pruebas UI estrictas parciales, sin auditoría Lighthouse/axe aplicable. |
| Documentación completa / demo | ❌ | Faltan README raíz, auditoría/plan iniciales, mapa, guion, entrega y ADR. |

## Defectos y deuda priorizados

1. **P1 — Reglas de casos incompletas:** backend rechaza duplicados de fila/columna y se validan los 30 seeds reales. Sigue pendiente el solver de unicidad basado en restricciones/pistas; comparar contra la respuesta privada no equivale a solver.
2. **P1 — Demo de autenticación:** TOTP configurado como acción requerida; hay que completar enrolamiento desde Keycloak y validar flujo Gateway/cliente sin revelar secretos.
3. **P1 — E2E de resultado:** demostrar fallo/compensación e idempotencia de saga con correlación, además del camino feliz y premio/XP.
4. **P2 — Progreso competitivo:** falta canal en tiempo real seguro (sin exponer tablero del rival) y prueba de desconexión/reconexión.
5. **P2 — Perfil y logros:** catálogo de 11 y evaluación por evento ya añadidos; falta vitrina con logros bloqueados/progreso y lectura CQRS de resumen/historial completa.
6. **P2 — Panel admin:** proteger todo el CRUD por ADMIN y bloquear publicación si el caso no pasa validación/solver; registrar auditoría.
7. **P2 — Estabilidad:** handler duplicado de logout y runner H04-03 corregidos; debe prevenirse la regresión con las suites.
8. **P2 — Contratos públicos:** agregar OpenAPI al gateway, versionar APIs, normalizar Problem Details y exportar colección reproducible.
9. **P2 — Operación/entrega:** healthchecks/dashboards/alertas, CI y un comando de arranque/prueba/seed verificado en entorno limpio.
10. **P3 — Documentación:** mapa de arquitectura, backlog actualizado, guion de demo y empaquetado sin artefactos ni secretos.

## Riesgos

- Se ejecuta parte de la integración en Windows/Docker; usuarios requiere su runner específico de PostgreSQL y partidas no tiene Python local instalado. Las cifras de pruebas dependen de los runners descritos.
- El inicio MFA necesita un código TOTP humano y no puede declararse probado por una ejecución headless.
- El cliente solo tiene preset de exportación Web; la exportación Windows debe añadirse y probarse antes de distribución ejecutable.
- El requisito amplio de «todas las HU completas» no se satisface únicamente con la regresión actual. Los estados parciales no deben presentarse en la sustentación como funcionalidad cerrada.
- No se ejecutó escaneo de CVE; el build verde no prueba ausencia de vulnerabilidades.

## Evidencia de cambios

Esta auditoría no modifica código de aplicación. Los entregables de planificación asociados están en `docs/PLAN.md`. El estado de trabajo de los repositorios era limpio al momento de iniciar este documento; no se realizaron commits.
