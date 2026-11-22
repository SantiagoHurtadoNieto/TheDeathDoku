# Guion de demo (10–15 min)

El guion distingue recorridos disponibles y puntos que no deben presentarse como cerrados hasta terminar la validación final.

1. **Contexto (1 min):** mostrar el diagrama de arquitectura y señalar Gateway, servicios, bases de datos y Kafka.
2. **Arranque (2 min):** desde la raíz ejecutar docker compose up --build -d; mostrar salud en Docker y Eureka.
3. **Acceso (2 min):** abrir Godot, iniciar OIDC con una cuenta local autorizada y completar el enrolamiento TOTP requerido. Nunca mostrar secretos o códigos en la grabación.
4. **Biblioteca y tablero (3 min):** elegir un caso, mostrar filtros, pistas, ocupabilidad, colocar personajes y enviar intento al backend.
5. **Modos (2 min):** mostrar rutas de Classic, Timed y Versus; marcar progreso rival realtime y compensaciones de saga como pendientes hasta tener evidencia E2E.
6. **Perfil (2 min):** abrir estadísticas, idioma ES/EN y tutorial; explicar logros como parciales mientras existan solo cuatro inicializados.
7. **Evidencia y preguntas (2 min):** enseñar runners en verde, correlación de eventos y los hallazgos abiertos del backlog.

## Datos de demo

Usar únicamente cuentas locales de desarrollo configuradas en Keycloak y el catálogo seed. Las credenciales se guardan fuera del repo en el entorno local. No copiar contraseñas, tokens ni códigos TOTP a este guion.

## Bloqueos antes de la sustentación

Confirmar enrolamiento TOTP; completar solver/seed, progreso realtime, saga con fallos demostrables y telemetría con correlationId; ejecutar la matriz restante según PLAN.md.
