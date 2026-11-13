# DeathDoku API regression

Colección Bruno que ejecuta el contrato público del stack a través del API Gateway
(`http://localhost:8765`). Cubre identidad, perfiles, casos, partidas contrarreloj,
partidas versus y controles de seguridad.

## Requisitos

1. Stack local levantado con el override de desarrollo:

   ```powershell
   docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
   docker compose ps
   ```

2. Fixtures de Keycloak creados una vez por entorno:

   ```powershell
   powershell -ExecutionPolicy Bypass -File infra/keycloak/dev-setup.ps1
   ```

   Ese script crea el cliente `hopedoku-test` y los usuarios `test-a`, `test-b` y
   `test-admin`. Es solo para desarrollo; consulta `infra/keycloak/README.dev.md`.

3. Contraseñas de prueba disponibles para Bruno, en variables de entorno del sistema o
   en `regression/.env` (ignorado por Git):

   ```dotenv
   KC_TEST_A_PASSWORD=...
   KC_TEST_B_PASSWORD=...
   KC_TEST_ADMIN_PASSWORD=...
   ```

   `dev-setup.ps1` puede escribir esas claves en `regression/.env` sin mostrar los
   valores, siempre que el archivo esté ignorado por Git.

4. CLI de Bruno fijado en **4.3.0** (última estable con más de dos semanas de
   antigüedad al crear esta colección):

   ```powershell
   npx --yes @usebruno/cli@4.3.0 --version
   ```

No se necesita instalar nada de forma global.

## Ejecutar

```powershell
Set-Location C:\dev\TheDeathDoku\regression
npx --yes @usebruno/cli@4.3.0 run --env local
```

Para comprobar que la colección es repetible, ejecútala dos veces seguidas:

```powershell
npx --yes @usebruno/cli@4.3.0 run --env local
npx --yes @usebruno/cli@4.3.0 run --env local
```

`--env local` selecciona `environments/local.bru`, que solo contiene valores no
secretos (`baseUrl`, `tokenUrl`, cliente de prueba y nombres de usuario). No es un
archivo dotenv.

## Cómo se obtienen los tokens

`collection.bru` ejecuta un `script:pre-request` antes de cada request:

1. Pide un token por contraseña al realm `hopedoku` para `test-a`, `test-b` y
   `test-admin`, usando el cliente público `hopedoku-test`.
2. Guarda los tokens y su caducidad en variables de runtime con `bru.setVar`.
3. Antes de cada request comprueba la caducidad y renueva **45 segundos antes** de los
   5 minutos de vida del access token.

Los tokens nunca se guardan en `environments/local.bru`, nunca se escriben en disco y
nunca se imprimen. `bru.setEnvVar` no se usa porque persiste valores en el proyecto.
Los mensajes de las aserciones no incluyen claims, tokens ni valores de identidad.

## Estructura

| Carpeta | Qué valida |
|---|---|
| `00-token` | 401 sin token, 401 con token alterado, ruta antigua `/usuarios/auth/**` sin token, `sub` UUID, `azp`, roles y vida de 5 minutos |
| `01-usuarios` | Creación idempotente del perfil, `PUT /me`, idioma válido e inválido, tutorial, stats y logros |
| `02-casos` | Listado, filtros, detalle, id inválido, rechazo de validación directa (sin y con Bearer), pistas y autorización de admin |
| `03-partidas-timed` | Límites 60/3600, validación interna mediante partidas, victoria, derrota, `positions` vacío, partida inexistente y cambio de stats |
| `04-partidas-versus` | Creación, listado, unión propia (400), unión del rival, progreso, cierre por un no participante (403), victoria, ranking e historial |
| `05-seguridad` | Suplantación de `X-User-Id`/`X-Roles` ignorada, ruta interna de resultados bloqueada, salud enrutada sin token y documentación pública |

La victoria con `timeLimitSeconds=3600` se registra como observación: el bono crece con
el tiempo restante, así que ese caso produce un bono muy alto. La aserción solo
comprueba que el bono no es negativo y que `xpDelta = 50 + bonus`.

La validación `POST /casos/cases/{id}/validate` es de uso interno. El Gateway responde
403 tanto sin autenticación como con un Bearer válido. Las pruebas de partidas
contrarreloj conservan la comprobación del camino autorizado: `partidas-service`
invoca directamente a `cases-service` con la credencial interna configurada.

## Comprobar el comportamiento por defecto del gateway

Con el Compose **base** (sin el override), el gateway solo acepta
`azp=hopedoku-godot`. Un token de `hopedoku-test` debe responder **401**:

```powershell
docker compose up -d --build
# obtener un token de test-a en una variable y llamar a /usuarios/users/me
# mostrando únicamente el código HTTP
```

Después vuelve a levantar el override de desarrollo:

```powershell
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

## Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| `Falta la variable de entorno KC_TEST_*` | No está en el entorno ni en `regression/.env` |
| `No se pudo obtener el token ... (HTTP 400, error invalid_grant)` | Usuarios sin crear, contraseña distinta o `CONFIGURE_TOTP` pendiente; ejecuta `dev-setup.ps1` |
| `HTTP 401` en todas las requests | El gateway no se recreó con `docker-compose.dev.yml` o falta `KEYCLOAK_ALLOWED_AZP` |
| `HTTP 503` en partidas | Keycloak, casos-service o usuarios-service no están listos |
| Fallo de `axios` o `jsonwebtoken` | El sandbox de Bruno no permite las librerías; repórtalo antes de cambiar de modo de ejecución |
