# Manual de usuario (versión de trabajo)

Este manual describe navegación existente y señala funciones que todavía son parciales. Está escrito para la aplicación Godot de escritorio.

## Abrir la aplicación

1. Inicia los servicios locales con Docker Compose y espera que casos, usuarios, Gateway y Keycloak estén disponibles.
2. Abre el proyecto death-doku/project.godot con Godot 4.7.2 y ejecútalo.
3. En el menú principal puedes elegir partida, contrarreloj, versus u Opciones.

## Cambiar idioma

En la esquina inferior derecha del menú usa el botón es/en. La selección se guarda localmente. Opciones mantiene un selector detallado de idioma.

## Iniciar sesión y perfil

Desde la biblioteca o Perfil, inicia el flujo de Keycloak en el navegador. En el primer acceso configura TOTP cuando Keycloak lo solicite. Vuelve a la aplicación al finalizar. El token debe renovarse mientras se usa el sistema; para cerrar sesión utiliza el botón correspondiente del perfil.

No compartas contraseñas, códigos TOTP, códigos de dispositivo ni tokens.

## Elegir un caso

Abre la biblioteca, selecciona categoría/dificultad y elige una tarjeta disponible. El catálogo se sincroniza desde MongoDB al iniciar casos-service. Un estado de progreso nuevo/en curso/resuelto no está implementado por completo.

## Resolver

Abre el caso y consulta sus pistas. Coloca personajes en casillas disponibles y respeta una persona por fila y por columna. Usa el control de validar para que el backend compruebe la propuesta. La solución no debe mostrarse al cliente antes de validarla.

Las notas persistentes, resaltado completo de pista, deshacer/rehacer y solver de unicidad están pendientes o parciales.

## Contrarreloj y versus

Los modos existen, pero no se debe asumir reloj autoritativo, progreso rival en tiempo real, reconexión o desempate hasta que la prueba E2E correspondiente esté cerrada. Si el servicio no está disponible, el cliente permite reintentar; los resultados online necesitan conectividad.

## Tutorial y estadísticas

El tutorial puede abrirse desde la interfaz. Perfil muestra estadísticas disponibles y logros; el catálogo de 11 logros está conectado a evaluación de resultados, aunque la vitrina/progreso visual sigue incompleta.

## Ayuda ante fallos

- “Servidor no disponible”: inicia Compose y revisa salud del Gateway y casos/users.
- Inicio vencido: vuelve a iniciar sesión; Keycloak renueva credenciales con el flujo OIDC.
- Biblioteca sin casos: espera la sincronización inicial del catálogo y revisa los logs del servicio de casos.

Las capturas ilustrativas del recorrido final se añadirán cuando la validación completa E2E y la exportación para Windows queden aprobadas.
