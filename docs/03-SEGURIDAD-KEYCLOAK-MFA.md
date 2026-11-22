# Seguridad, Keycloak y MFA

## Realm

Realm: `hopedoku`  
Cliente público: `hopedoku-godot`  
Audiencia: `hopedoku-gateway`  
Grant: Device Authorization Grant

## TOTP obligatorio

El realm exige la acción `CONFIGURE_TOTP`. Los usuarios deben registrar un segundo factor antes de completar el login. El cliente no debe aceptar bypass.

## Flujo desde Godot

1. Godot solicita un código de dispositivo a Keycloak.
2. Abre `verification_uri` en el navegador.
3. El usuario inicia sesión y completa TOTP.
4. Godot realiza polling respetando `interval` y `slow_down`.
5. Recibe access/refresh token.
6. Envía solo el Bearer al Gateway.

Los tokens permanecen en memoria y no se guardan en disco ni en logs.

## Roles

| Rol | Permisos |
|---|---|
| USER | Perfil, casos, partidas e historial propios |
| ADMIN | Operaciones administrativas y catálogo |
| SERVICE | Acceso interno limitado a progreso y resultados |

## Usuarios semilla

| Usuario | Roles | Uso |
|---|---|---|
| jugador1 | USER | Jugador de regresión |
| admin1 | USER, ADMIN | Administrador semilla |

Las contraseñas se toman de `.env` y no deben quedar versionadas.

## Cabeceras

El Gateway elimina `X-User-Id` y `X-Roles` recibidas del cliente y las reemplaza con claims validados.
