# DeathDoku API regression

Colección Bruno para ejecutar en orden contra el gateway local. Requiere el stack ya levantado desde la raíz del proyecto:

```powershell
docker compose up -d
docker compose ps
```

La colección usa `environments/local.bru` para `baseUrl`. No guarda tokens, credenciales ni secretos: cada ejecución registra usuarios A y B con nombres, emails y contraseñas temporales generados en memoria.

## Ejecutar

El CLI oficial de Bruno se instala con npm y el ejecutable se llama `bru`:

```powershell
npm install -g @usebruno/cli
Set-Location C:\dev\TheDeathDoku\regression
bru run --env local
```

También se puede ejecutar sin instalación global:

```powershell
Set-Location C:\dev\TheDeathDoku\regression
npx --yes @usebruno/cli run --env local
```

Ejecuta las carpetas `00-auth` a `05-seguridad` en orden. No se encontró documentación oficial de un CLI llamado “Santiago”; los comandos anteriores son los documentados para Bruno CLI.

## Lectura de resultados

- Cada request valida el estado HTTP y la forma relevante del JSON.
- La CLI imprime requests y assertions fallidos; revisa el nombre del request y el mensaje de la assertion para ubicar la causa.
- Requests protegidos necesitan las variables runtime creadas por `00-auth`; ejecuta la colección completa y en orden, no una carpeta aislada.
- El último request de `05-seguridad` se llama **OBSERVACIÓN**. Imprime `BONO_OBSERVACION=<valor>` al terminar, sin fijar un umbral sensible al tiempo.
- Si hay errores de conexión, verifica `docker compose ps` y `http://localhost:8765/actuator/health` antes de interpretar fallas funcionales.

Documentación oficial consultada: [instalación y ejecución del CLI Bruno](https://www.usebruno.com/product/cli), [Bruno CLI](https://docs.usebruno.com/bru-cli/overview), [scripts y variables](https://docs.usebruno.com/testing/script/javascript-reference) y [variables de entorno](https://docs.usebruno.com/variables/environment-variables).
