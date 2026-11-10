# Token de desarrollo para el cliente Godot

`dev_token.ps1` pide un token con **Direct Access Grant** al cliente público
`hopedoku-test`, usando un usuario de prueba creado por `dev-setup.ps1`, y deja
las credenciales **solo en variables de entorno de tu sesión de PowerShell**.

- No imprime tokens, contraseñas ni el contenido del `.env`.
- No escribe nada en disco.
- El cliente Godot solo las lee desde el editor (`OS.has_feature("editor")`);
  un `.exe` exportado, aunque sea de depuración, nunca las usa.

## Requisitos

1. Stack levantado con el compose de desarrollo (es el único que autoriza el
   `azp` de `hopedoku-test` en el gateway):

   ```powershell
   docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
   ```

2. `KC_TEST_A_PASSWORD` (o la del usuario que elijas) presente en `.env`, en la
   raíz del repositorio. `dev-setup.ps1` la genera si falta.

## Uso

```powershell
cd C:\dev\TheDeathDoku
. .\infra\keycloak\dev_token.ps1
```

El punto inicial es importante: hace *dot-sourcing* para que las variables
queden en tu sesión actual. Si lo ejecutas con `powershell -File`, el proceso
termina y las variables desaparecen con él.

Variables que se definen:

| Variable | Contenido |
| --- | --- |
| `DEATHDOKU_DEV_TOKEN` | access token (solo en memoria) |
| `DEATHDOKU_DEV_REFRESH_TOKEN` | refresh token (solo en memoria) |
| `DEATHDOKU_DEV_TOKEN_EXPIRES_AT` | instante de caducidad, en segundos Unix |
| `DEATHDOKU_CLIENT_ID` | `hopedoku-test` |

Parámetros opcionales: `-Username test-b`, `-ClientId hopedoku-test`, `-Realm hopedoku`,
`-KeycloakBase http://localhost:8180`.

## Abrir el editor de Godot con esa sesión

El editor hereda las variables del proceso que lo lanza, y el juego que se
ejecuta con F5 hereda las del editor. Lánzalo **desde la misma ventana de
PowerShell**:

```powershell
& "C:\Users\USUARIO\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --editor --path "C:\dev\TheDeathDoku\death-doku"
```

`-e` / `--editor` inicia el editor en lugar de ejecutar una escena, y
`--path <directorio>` apunta al proyecto (documentación oficial de la línea de
comandos de Godot 4.7). Dentro del editor, F5 ejecuta el juego con las mismas
variables.

## Caducidad y refresh

El access token de `hopedoku-test` dura unos 5 minutos. El cliente refresca
automáticamente 60 s antes de caducar (margen configurable en
`death-doku/project.godot`, `deathdoku/http/refresh_margin_seconds`) y, si el
servidor responde 401, intenta un único refresh y un único reintento. Cuando el
refresh falla, borra la sesión y emite `UNAUTHORIZED`.

Para renovar a mano, vuelve a ejecutar el script en la misma sesión.

## Problemas frecuentes

| Síntoma | Causa |
| --- | --- |
| El gateway responde 401 con el token de `hopedoku-test` | Falta `KEYCLOAK_ALLOWED_AZP` en `docker-compose.dev.yml` o el gateway no se recreó. |
| `Keycloak rechazó la petición de token (HTTP 401)` | Contraseña del `.env` distinta a la del usuario, o el usuario no existe. Ejecuta `dev-setup.ps1`. |
| `HTTP 400 invalid_grant` | El usuario tiene acciones requeridas pendientes (por ejemplo TOTP). `dev-setup.ps1` las limpia. |
| Godot no ve la sesión | El editor se abrió desde otra terminal o desde el lanzador del sistema, no desde esta sesión. |
