# Preguntas de sustentación

1. **¿Qué problema resuelve DeathDoku?** Permite deducir posiciones de personajes en una escena a partir de pistas y confirmar la solución desde el backend.
2. **¿Por qué se conserva Godot?** Es el frontend existente, funcional y probado; migrarlo reescribiría la interfaz sin resolver una brecha de requisito.
3. **¿Qué hace el Gateway?** Centraliza rutas y valida JWT de Keycloak; propaga identidad/roles confiables a servicios internos.
4. **¿Cómo se aplica MFA?** El realm Keycloak requiere enrolamiento TOTP; se debe demostrar con enrolamiento real del usuario en el entorno de demo.
5. **¿Qué significa arquitectura hexagonal?** El dominio define reglas; casos de uso dependen de puertos; REST, BD, Kafka y clientes externos son adaptadores.
6. **¿Qué es DDD aquí?** Modelar el lenguaje y reglas del juego en dominios de casos, partidas y progreso. La protección ArchUnit sigue pendiente.
7. **¿Qué hace cases-service?** Mantiene catálogo, pistas, solución privada, administración y validación de colocaciones.
8. **¿Cómo se protege la solución?** El esquema Mongo la excluye de consultas públicas y el adaptador la selecciona expresamente solo para validar.
9. **¿Cómo se valida una partida?** El backend compara posiciones con la solución almacenada y ahora también exige que la definición respete fila/columna.
10. **¿Hay solver de unicidad?** Todavía no. El endpoint valida la respuesta privada; no prueba unicidad lógica desde las pistas.
11. **¿Por qué se usa MongoDB?** Para almacenar documentos de casos, pistas, habitaciones y tablero visual.
12. **¿Por qué PostgreSQL?** Para persistencia relacional de usuarios, resultados, logros y estado durable de eventos.
13. **¿Qué se guarda en Redis?** Estado efímero/operativo de partidas y estructuras de tiempo limitado.
14. **¿Para qué se usa Kafka?** Para eventos de finalización/progreso, consumidores, DLQ y outbox de la saga.
15. **¿Cómo se manejan duplicados de eventos?** Usuarios verifica eventos/resultados por identificadores y mantiene datos de resultado de forma idempotente; se requieren pruebas E2E adicionales.
16. **¿Qué pasa si Kafka falla?** Outbox/reintentos conservan eventos pendientes y DLQ registra agotamiento; ejecutar la demo de fallo y recuperación antes de presentar el cierre.
17. **¿Qué es CQRS?** Separar el modelo de escritura de una proyección de lectura; el read model de ranking/progreso todavía está incompleto.
18. **¿Qué es una saga?** Una coordinación de pasos distribuidos con estados y compensación cuando una etapa falla; el escenario E2E completo está pendiente.
19. **¿Cómo se determina el ganador versus?** Debe hacerlo servidor por timestamp autoritativo; probar desempate/abandono y no confiar en el reloj del cliente.
20. **¿Cómo se limita el contrarreloj?** El servidor debe fijar y comprobar vencimiento; el cliente solo presenta el tiempo. Falta cerrar evidencia E2E.
21. **¿Cómo se mide progreso?** Users mantiene estadísticas y resultados; progreso rival realtime requiere canal dedicado pendiente.
22. **¿Cómo se evalúan logros?** El consumidor de MatchFinished aplica condiciones de victorias, XP y racha; el catálogo contiene 11 definiciones.
23. **¿Qué monitorea Prometheus?** Métricas HTTP/servicio; aún deben completarse paneles/alertas de negocio y trazas con correlationId.
24. **¿Qué pruebas pasan actualmente?** Casos 41/41, usuarios 128 (2 omitidas), partidas aisladas, Gateway 24, Eureka 1 y Godot RUNNER OK.
25. **¿Qué brechas reconoce el equipo?** Solver, canal realtime, completitud de i18n/UX, OpenAPI agregado, saga E2E, ArchUnit y escaneo de CVE.
