# Keycloak dev fixtures (solo desarrollo local)

`dev-setup.ps1` crea en el realm **activo** `hopedoku` los elementos que necesita la
colección Bruno. No modifica `realm-hopedoku.json`, no reimporta el realm y no toca
volúmenes.

> **Solo desarrollo.** Este script crea un cliente con Direct Access Grants y tres
> usuarios con contraseña. No lo ejecutes contra un Keycloak compartido o de
> producción: la guardia de URL lo impide salvo que uses `-AllowRemote`.

## Qué crea

| Elemento | Detalle |
|---|---|
| Cliente público `hopedoku-test` | Direct Access Grants activado, flujos de navegador desactivados, scopes `basic`, `roles`, `profile`, `email` |
| `test-a` | rol `USER` |
| `test-b` | rol `USER` |
| `test-admin` | roles `USER` y `ADMIN` |

A los tres usuarios se les elimina la acción requerida `CONFIGURE_TOTP` que Keycloak
copia por defecto al crearlos. Sin ese paso, el token por contraseña responde
`400 invalid_grant` con “Account is not fully set up”.

Es idempotente: volver a ejecutarlo actualiza el cliente, restablece las contraseñas
al valor del `.env` y deja los roles en el estado esperado.

## Requisitos

1. Stack levantado, al menos Keycloak:

   ```powershell
   docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
   ```

2. `.env` en la raíz con las credenciales de administración y las tres contraseñas de
   prueba (no las compartas ni las imprimas):

   ```dotenv
   KC_HOSTNAME=http://localhost:8180
   KC_BOOTSTRAP_ADMIN_USERNAME=...
   KC_BOOTSTRAP_ADMIN_PASSWORD=...
   KC_TEST_A_PASSWORD=...
   KC_TEST_B_PASSWORD=...
   KC_TEST_ADMIN_PASSWORD=...
   ```

   También se aceptan como variables de entorno del sistema, que tienen prioridad
   sobre el `.env`. `.env` está ignorado por Git.

## Ejecutar

```powershell
powershell -ExecutionPolicy Bypass -File infra/keycloak/dev-setup.ps1
```

Opciones:

| Opción | Efecto |
|---|---|
| `-Clean` | Borra el cliente y los tres usuarios de prueba. No toca el realm, `jugador1`, `admin1` ni los volúmenes |
| `-NoBrunoEnv` | No escribe las contraseñas en `regression/.env` |
| `-AllowRemote` | Desactiva la guardia que exige `localhost`/`127.0.0.1` |

Sin `-NoBrunoEnv`, el script escribe en `regression/.env` las tres claves
`KC_TEST_*` **solo si el archivo está ignorado por Git** (`git check-ignore`), **solo
si faltan** y **sin mostrar los valores**. Si una clave ya existe con otro valor,
avisa y no la sobrescribe.

## Cómo quitarlo

1. Borra cliente y usuarios:

   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/keycloak/dev-setup.ps1 -Clean
   ```

2. Revierte el override de desarrollo: elimina `KEYCLOAK_ALLOWED_AZP` de
   `docker-compose.dev.yml` (el Compose base nunca lo define y por defecto el gateway
   solo acepta `hopedoku-godot`).
3. Si quieres borrar también las contraseñas, quita las claves `KC_TEST_*` de `.env` y
   `regression/.env`. No borres los volúmenes.

## Seguridad

- El cliente y los usuarios viven en el mismo realm que usa el cliente Godot. El
  gateway base rechaza sus tokens (se comprueba en la verificación), pero Keycloak
  seguiría emitiéndolos mientras existan. Ejecuta `-Clean` antes de reutilizar el
  volumen en un entorno real.
- El token de administración y las contraseñas permanecen en memoria; el script no los
  imprime.
- `Direct Access Grants` está desaconsejado por RFC 9700. Aquí se usa únicamente para
  que la regresión local no dependa de pasos humanos (device flow + TOTP).

## Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| `No se pudo autenticar como administrador` | `KC_BOOTSTRAP_ADMIN_*` incorrectos o `admin-cli` sin Direct Access Grants |
| `Account is not fully set up` | El `PUT` con `requiredActions: []` no se aplicó; vuelve a ejecutar el script |
| `regression/.env` no se actualiza | Git no lo considera ignorado; revisa `.gitignore` |
| El gateway responde 401 con un token de `hopedoku-test` | Falta `KEYCLOAK_ALLOWED_AZP` en `docker-compose.dev.yml` o el gateway no se recreó |
