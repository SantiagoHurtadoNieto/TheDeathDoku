# Keycloak PoC: Device Authorization + TOTP

PoC independiente de la autenticación HS256 actual. No configura el gateway ni los servicios.

## Requisitos

- Docker Engine/Desktop y Docker Compose v2.20 o posterior para usar `include:`. En esta máquina, `docker compose version` reportó v5.2.0.
- Python 3.10+ solo para verificar el JWT.

La imagen se fija en Keycloak 26.8.2. Esta versión dispone de `start-dev` y DB de desarrollo `dev-file` (H2), persistida en el volumen `keycloak_data`. El hostname se configura con `KC_HOSTNAME`, por defecto `http://localhost:8180`.

Si Compose es anterior a 2.20, el `include:` raíz no está disponible. En ese caso, arranca con ambos archivos:

```powershell
docker compose -f docker-compose.yml -f infra/keycloak/docker-compose.keycloak.yml up -d
docker compose -f docker-compose.yml -f infra/keycloak/docker-compose.keycloak.yml ps
```

El archivo de servicio está preparado para combinarse desde la raíz del proyecto. Para detener el PoC con ese modo, agrega ambos `-f` a `docker compose down`; `down -v` elimina también sus datos persistidos.

## Configuración y arranque

Agrega a `.env` las variables `KC_HOSTNAME`, `KC_BOOTSTRAP_ADMIN_USERNAME`, `KC_BOOTSTRAP_ADMIN_PASSWORD`, `KC_JUGADOR1_PASSWORD` y `KC_ADMIN1_PASSWORD`. Usa contraseñas privadas solo para esta prueba. `.env.example` contiene los nombres y valores de ejemplo.

```powershell
docker compose version
docker compose config --quiet
$started = Get-Date
docker compose up -d keycloak
docker compose ps keycloak
docker compose logs -f keycloak
```

Espera `healthy` antes de continuar. La duración medida desde `$started` hasta que `docker inspect` indique `healthy` es el tiempo de arranque desde cero. `start-dev` y H2 son solo para la PoC: para una VPS, usa `start` con HTTPS/TLS, hostname DNS público, una base PostgreSQL externa o administrada con respaldo, secretos en un gestor de secretos, restricciones de red y límites/observabilidad dimensionados para uso real. No expongas el puerto de administración/health al público.

Realm `hopedoku` se importa al iniciar. Keycloak soporta placeholders `${VARIABLE}` dentro del JSON del realm; por eso las dos contraseñas se interpolan desde el entorno. `jugador1` y `admin1` tienen `CONFIGURE_TOTP` como acción requerida; ambos reciben USER y solo `admin1` recibe ADMIN adicional. El claim de roles esperado es `realm_access.roles`.

## Flujo Device Authorization con curl.exe

Los endpoints siguen la documentación OIDC de Keycloak:

- Solicitud del código: `POST /realms/hopedoku/protocol/openid-connect/auth/device`
- Intercambio/sondeo: `POST /realms/hopedoku/protocol/openid-connect/token`
- Verificación de firma: `/realms/hopedoku/protocol/openid-connect/certs`

### A. Solicita el código de dispositivo

```powershell
$device = curl.exe -sS -X POST "http://localhost:8180/realms/hopedoku/protocol/openid-connect/auth/device" `
  -H "Content-Type: application/x-www-form-urlencoded" `
  --data-urlencode "client_id=hopedoku-godot"
$device = $device | ConvertFrom-Json
$device | Select-Object device_code, user_code, verification_uri, verification_uri_complete, interval, expires_in
```

### B. Primera autorización: configurar TOTP

Detén aquí el script/agente y entrega `user_code` y `verification_uri_complete`. En una **ventana privada nueva**, abre `verification_uri_complete`, inicia sesión con `jugador1` y la contraseña de `KC_JUGADOR1_PASSWORD`, configura un autenticador TOTP y confirma el primer código. Una ventana privada nueva evita que una sesión SSO previa salte pasos. No continúes hasta que la persona indique que terminó.

### C. Sondea respetando interval y slow_down

Tras recibir confirmación, usa el mismo `$device.device_code`. El primer sondeo espera `interval` segundos. `authorization_pending` conserva ese intervalo; `slow_down` lo incrementa en 5 segundos para los siguientes sondeos, conforme al Device Authorization Grant.

```powershell
$interval = [int]$device.interval
while ($true) {
  Start-Sleep -Seconds $interval
  $raw = curl.exe -sS -X POST "http://localhost:8180/realms/hopedoku/protocol/openid-connect/token" `
    -H "Content-Type: application/x-www-form-urlencoded" `
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" `
    --data-urlencode "device_code=$($device.device_code)" `
    --data-urlencode "client_id=hopedoku-godot"
  $reply = $raw | ConvertFrom-Json
  if ($reply.access_token) { break }
  if ($reply.error -eq "authorization_pending") { continue }
  if ($reply.error -eq "slow_down") { $interval += 5; continue }
  throw "Device flow falló: $($reply.error) $($reply.error_description)"
}
$token = $reply.access_token
```

### D. Segunda autorización: comprobar el desafío OTP

Solicita un **nuevo** device code con el paso A. Detente otra vez y entrega el nuevo código y URL. Abre la URL en otra **ventana privada nueva**, inicia sesión con el mismo usuario y confirma que Keycloak presenta el campo para el código TOTP. Introduce el TOTP actual; solo después de la confirmación sondea el segundo device code con el mismo bucle de C. Esta separación permite afirmar si TOTP fue exigido en la segunda autorización. No reutilices `$device` ni la sesión del navegador anterior.

## Decodificar y validar el token

No pegues el token en un sitio externo. Para mostrar únicamente claims no secretos:

```powershell
$parts = $token.Split('.')
$payload = $parts[1].Replace('-', '+').Replace('_', '/')
$payload += '=' * ((4 - $payload.Length % 4) % 4)
$claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
[pscustomobject]@{
  iss = $claims.iss
  sub = $claims.sub
  exp = $claims.exp
  preferred_username = $claims.preferred_username
  roles = ($claims.realm_access.roles -join ',')
}
```

Crear un venv fuera del proyecto y validar la firma RS256 contra JWKS y el emisor esperado:

```powershell
py -m venv "$env:TEMP\hopedoku-keycloak-venv"
& "$env:TEMP\hopedoku-keycloak-venv\Scripts\python.exe" -m pip install -r infra/keycloak/requirements-verify.txt
& "$env:TEMP\hopedoku-keycloak-venv\Scripts\python.exe" infra/keycloak/verify_token.py $token
```

El script exige `iss` y `exp`, valida expiración/firma y solo permite RS256. También muestra `sub`; si el token no lo incluye, aparecerá como `null` para que esa ausencia quede visible.

## Issuer público y JWKS interno

El token emitido localmente debe tener `iss=http://localhost:8180/realms/hopedoku`. Desde un contenedor, el JWKS se alcanza por `http://keycloak:8080/realms/hopedoku/protocol/openid-connect/certs`. Al configurar el gateway en una fase futura, compara el claim `iss` contra la URL pública exacta y configura la descarga JWKS con la dirección interna. No uses `http://keycloak:8080/...` como issuer esperado: eso no coincide con el token. La configuración concreta dependerá del validador OIDC que se adopte y no se aplica en esta PoC.

## Comprobación de memoria y regresión

```powershell
docker stats --no-stream
docker stats --no-stream keycloak
```

Con Keycloak arriba y la colección de Bruno instalada, ejecuta la colección completa del directorio `regression/` siguiendo su README. La expectativa informada para el stack actual es 52/52; registra la salida real y cualquier fallo.

## Limpieza

```powershell
docker compose stop keycloak
```

El volumen `keycloak_data` conserva H2, realm y enrolamiento TOTP entre reinicios. Para reiniciar la PoC desde cero, `docker compose down -v` elimina también datos y credenciales MFA. Ejecuta ese comando solo si aceptas perder el estado de prueba.
