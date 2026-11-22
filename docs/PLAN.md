# Plan de cierre de DeathDoku

**Fecha:** 22 de noviembre de 2026  
El orden sigue el prompt de trabajo. Las estimaciones son horas de implementación y validación, no fechas prometidas. Los commits los hará manualmente el usuario.

## Fases

| Fase | Estimación | Prioridad | Trabajo | Criterio de salida |
|---|---:|---|---|---|
| 1. Auditoría y decisiones | 4 h | P0 | Inventario, builds, suites, matriz HU/requisitos, riesgos y plan. | `AUDITORIA_INICIAL.md` y este plan revisables; sin cambios de aplicación. |
| 2. Regresión del cliente y contrato de casos | 8–12 h | P0 | Reparar selector compacto ES/EN y señal duplicada; actualizar pruebas del menú; verificar API real y errores/reintentos en Godot. | Import y 10+ regresiones pasan; ninguna pantalla vacía al fallar un servicio. |
| 3. Solver y dominio de casos | 12–18 h | P0 | Modelar tamaños/zonas/ocupabilidad/restricciones; solver con backtracking/propagación y unicidad; validar seed y publicación admin. | Todos los seeds publicados son consistentes y tienen solución única; pruebas dominio/API verdes. |
| 4. Reglas de tablero e historia | 18–28 h | P1 | Colocación accesible, conflicto fila/columna, notas persistidas, pistas aplicadas, deshacer/rehacer, identificación asesino y resumen de resolución. | HU-01–07 con aceptación y cobertura; regresión Godot completa verde. |
| 5. Versus, reloj y saga | 18–28 h | P1 | Progreso SSE/WebSocket sin tablero rival, presencia/reconexión; autoridad del reloj; recompensa, empate/abandono; compensaciones e idempotencia. | HU-08–14 demostradas con camino feliz y fallos reproducibles con correlationId. |
| 6. Perfil, logros y seguridad | 12–18 h | P1 | Completar dashboard/tiempos; 10+ logros event-driven; proteger roles; verificar TOTP/refresh/logout y permisos por rol. | HU-15–18 E2E; MFA real se completa con el usuario enrolando su autenticador. |
| 7. Tutorial, i18n y calidad visual | 10–16 h | P1 | Tutorial 4×4 persistido, ES/EN en caliente para interfaz/errores/casos; teclado, foco, patrones y reduced motion. | HU-19/20 verificadas; UI sin cadenas visibles sin traducir. |
| 8. Administración y arquitectura | 12–20 h | P2 | CRUD admin con drafts, validación solver, auditoría; ArchUnit; cerrar DTO/MapStruct y puertos/adaptadores que falten. | HU-21 y reglas de arquitectura probadas. |
| 9. Observabilidad, API y operación | 10–16 h | P2 | OpenAPI agregado, versionado y Problem Details; dashboards/alertas/healthchecks; runner H04-03; scripts up/down/seed/test y CI. | Stack arranca/prueba de forma reproducible y servicios son observables. |
| 10. Empaquetado y demo | 8–12 h | P2 | Guion, datos demo, prueba limpia, exportación Windows/Web, manuales y zip limpio. | Demo repetible 10–15 min y paquete verificable sin secretos/artefactos. |

**Estimación restante indicativa:** 112–168 h incluyendo las fases no empezadas; puede bajar si una parte del requisito ya está cubierta y las pruebas la demuestran. La fase 1 se ejecutó en la auditoría actual.

## Avance de esta ejecución

- Fase 1: auditoría y plan publicados.
- Fase 2 (parcial): Godot recupera selector ES/EN compacto y conserva Opciones; duplicado de logout removido. El backend de casos rechaza soluciones con dos personajes en misma fila/columna y la prueba usa los 30 seeds activos.
- Fase 3 (parcial): seed clasificado con 3 casos en HOGAR/OFICINAS/TRABAJO/TURISTICO y tablero 9x9 agregado; el test estructural valida categorías y dimensiones. Solver de unicidad, filtro de estado y flujo admin publicable siguen pendientes.
- Fase 6/7 (parcial): catálogo de logros ampliado a 11 y menú carga/persiste preferencia local ES/EN; vitrina, progreso y traducciones integrales siguen pendientes.
- Runner H04-03 corregido para no invocar Kafka cuando solo inicia Redis.
- No se hicieron commits.

## Orden de ejecución inmediato

1. Trazar el contrato real de casos entre cliente y backend; diseñar restricciones estructuradas y solver de unicidad sin leer pistas de texto libre como código.
2. Cerrar filtros de estado/preview y panel admin con borrador/publicación, validación de caso y auditoría.
3. Completar el camino de cierre de partida y fallos de saga con evidencia/correlationId.
5. Cerrar requisitos de perfil, realtime, tutorial, i18n y accesibilidad por prioridad de aceptación.
6. Finalizar documentación, escaneo de dependencias y empaquetado de entrega.

## Reglas de validación

- Tras cada fase: ejecutar el build y la suite de los módulos modificados, además de la regresión pertinente.
- Integraciones de Kafka/Redis/PostgreSQL/Mongo se prueban con los runners aislados documentados; no se confunden fallos por dependencias ausentes con defectos del dominio.
- Todo fallo de saga debe ser idempotente y correlacionable; los logs y capturas de demo no incluyen tokens, contraseñas ni códigos TOTP.
- No borrar datos persistentes del usuario ni volúmenes compartidos como parte de las pruebas.
- No se crean commits; mantener los cambios en el árbol de trabajo para revisión manual.
