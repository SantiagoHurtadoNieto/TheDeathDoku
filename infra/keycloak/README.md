# Keycloak PoC: Device Authorization + TOTP

PoC independiente del JWT HS256 actual. No integra Keycloak con el gateway ni con los servicios.

## Configuración

Compose incluye este servicio desde la raíz del proyecto. Se requiere Compose 2.20 o superior para `include:`; con una versión anterior usa ambos archivos explícitamente:

```powershell
docker compose -f docker-compose.yml -f infra/keycloak/docker-compose.keycloak.yml up -d keycloak
```

La imagen está fijada en Keycloak 26.8.2. `start-dev` usa H2 en el volumen `thedeathdoku_keycloak_data` y sirve únicamente para esta prueba local. El hostname se toma de `KC_HOSTNAME` (por defecto `http://localhost:8180`). Los secretos de arranque y las contraseñas de prueba se leen de `.env`; no los incluyas en logs ni los compartas.

El cliente público `hopedoku-godot` tiene asignados como scopes predeterminados `basic`, `roles`, `profile` y `email`. `basic` aporta los mappers de `sub` y `auth_time`; `roles` agrega los roles de realm en `realm_access.roles`. `jugador1` tiene USER, y `admin1` USER y ADMIN. Ambos requieren `CONFIGURE_TOTP` después de importar.

## Reimportar solo Keycloak desde cero

Este proceso elimina el enrolamiento TOTP y el estado H2 de Keycloak. Primero comprueba los volúmenes y el montaje exacto; detén únicamente Keycloak y elimina únicamente su volumen:

```powershell
docker volume ls
docker inspect thedeathdoku-keycloak-1 --format '{{json .Mounts}}'
docker compose stop keycloak
docker compose rm -f keycloak
docker volume rm thedeathdoku_keycloak_data
docker compose up -d keycloak
docker compose logs keycloak
```

Se elimina el contenedor detenido para liberar el montaje del volumen; `docker compose rm -f keycloak` no quita volúmenes. No uses `docker compose down -v`: eliminaría también los volúmenes de otros servicios. Confirma en los logs `Realm 'hopedoku' imported` y espera que el contenedor esté healthy. Las contraseñas permanecen configuradas desde `.env`, pero cada usuario debe enrolar TOTP otra vez. Borra la entrada TOTP antigua de tu app autenticadora antes de escanear el QR nuevo.

## Device Authorization Grant

Endpoints de Keycloak:

- Device authorization: `POST http://localhost:8180/realms/hopedoku/protocol/openid-connect/auth/device`
- Token y refresh: `POST http://localhost:8180/realms/hopedoku/protocol/openid-connect/token`
- JWKS: `http://localhost:8180/realms/hopedoku/protocol/openid-connect/certs`

Solicita el código de dispositivo con `curl.exe` y guarda el objeto solo en memoria de PowerShell. Nunca imprimas `device_code`, access token o refresh token completos:

```powershell
$device = (curl.exe -sS -X POST 'http://localhost:8180/realms/hopedoku/protocol/openid-connect/auth/device' `
  -H 'Content-Type: application/x-www-form-urlencoded' `
  --data-urlencode 'client_id=hopedoku-godot' | ConvertFrom-Json)
# Entrega al usuario únicamente user_code y verification_uri_complete.
$device.user_code
$device.verification_uri_complete
```

Para el primer enrolamiento, abre `verification_uri_complete` en una ventana privada nueva, inicia sesión como `jugador1`, configura el TOTP con el QR nuevo y confirma con el código actual de la app. Ten la app autenticadora lista. La ventana privada evita que una sesión SSO existente omita la pantalla de configuración. Espera la confirmación humana antes de sondear.

Sondea respetando el `interval` devuelto: `authorization_pending` conserva el intervalo y `slow_down` lo aumenta en 5 segundos. El código de dispositivo caduca según `expires_in`.

## Inspección y validación del token

`verify_token.py` primero decodifica el payload sin verificar y muestra únicamente nombres y claims seleccionados; luego valida RS256, issuer, expiración y presencia de `iss`, `sub` y `exp`. No imprime el JWT. Para evitar colocar el token en argumentos del proceso, pásalo por stdin.

```powershell
py -m venv "$env:TEMP\hopedoku-keycloak-venv"
& "$env:TEMP\hopedoku-keycloak-venv\Scripts\python.exe" -m pip install -r infra/keycloak/requirements-verify.txt
$token | & "$env:TEMP\hopedoku-keycloak-venv\Scripts\python.exe" infra/keycloak/verify_token.py --token-stdin
```

No copies el token a sitios externos, archivos o logs. Al presentar resultados, comparte solo valores de claims no secretos y nunca la cadena JWT.

## Refresh token

La respuesta inicial del token contiene `refresh_token` y `refresh_expires_in` (vigencia del refresh token), además de `expires_in` (vigencia del access token). Solicita uno nuevo sin volver a autorizar:

```powershell
curl.exe -sS -X POST 'http://localhost:8180/realms/hopedoku/protocol/openid-connect/token' `
  -H 'Content-Type: application/x-www-form-urlencoded' `
  --data-urlencode 'grant_type=refresh_token' `
  --data-urlencode 'client_id=hopedoku-godot' `
  --data-urlencode "refresh_token=$($reply.refresh_token)"
```

Mantén la respuesta en memoria; no la imprimas porque incluye credenciales portadoras.

## Issuer público y JWKS interno

Desde el host, el issuer esperado del token es `http://localhost:8180/realms/hopedoku`. Los contenedores descargan las claves por `http://keycloak:8080/realms/hopedoku/protocol/openid-connect/certs`. La configuración futura del gateway debe comparar `iss` con la URI pública exacta y permitir una URI JWKS interna independiente; no debe sustituir el issuer esperado por `http://keycloak:8080/...`. El discovery interno puede anunciar el issuer público si `KC_HOSTNAME` está correctamente configurado.

Si el gateway se migra a Spring Security Resource Server, la configuración recomendada separa issuer esperado y URL de claves. `issuer-uri` valida el claim `iss`; `jwk-set-uri` permite descargar las claves por la red interna sin depender del discovery para localizarlas:

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${KC_ISSUER_URI:http://localhost:8180/realms/hopedoku}
          jwk-set-uri: ${KC_JWKS_URI:http://keycloak:8080/realms/hopedoku/protocol/openid-connect/certs}
```

Esto es una recomendación para una futura configuración del gateway; esta PoC no modifica ni integra el gateway.

Para una VPS cambia `start-dev` por `start`, usa HTTPS con hostname DNS público y certificados válidos, PostgreSQL con respaldo, secretos gestionados fuera de `.env`, red restringida y límites/monitorización dimensionados para producción.
