# Despliegue en Azure

Este paquete prepara un despliegue de **un solo nodo** sobre Ubuntu 24.04 en una VM de Azure. Bicep crea la red, IP estática, reglas de firewall, ACR, Key Vault, identidad administrada, discos persistentes y VM. Docker Compose ejecuta los servicios existentes; Caddy publica únicamente la API y Keycloak por HTTPS.

Esta configuración sirve para una primera publicación, pruebas con usuarios y cargas pequeñas. No ofrece alta disponibilidad: la VM, PostgreSQL, MongoDB, Redis, Kafka, Eureka y Keycloak son componentes de un solo nodo. Antes de usarla para producción con requisitos de continuidad, define copias de seguridad y recuperación, y migra las bases de datos y el broker a servicios administrados.

## Requisitos

- Suscripción de Azure con capacidad para `Standard_B4s_v2` (4 vCPU, 16 GiB) en la región elegida. En la suscripción estudiantil de esta instalación, `spaincentral` pasó el preflight de capacidad; otras tallas y regiones probaron estar sin capacidad. El tamaño predeterminado es configurable con `-VmSize`.
- Azure CLI 2.73.0 o posterior, OpenSSH (`ssh` y `scp`) y PowerShell. Las imágenes se compilan en la VM y se publican en ACR con un token temporal; esto funciona en suscripciones Student que bloquean ACR Tasks y no requiere Docker Desktop local.
- Permisos para crear grupos de recursos, VM, red, ACR y Key Vault, y para asignar roles RBAC. El script asigna al despliegue `AcrPush` solo en ese ACR y `Key Vault Secrets Officer` solo en ese vault; asigna a la identidad de la VM únicamente `AcrPull` y `Key Vault Secrets User`. Se requiere permiso de administración de roles para crear esas asignaciones.
- Para uso permanente, un dominio propio y dos nombres DNS: uno para la API y otro para Keycloak. Los registros A deben apuntar a la IP estática de la VM. Para una demostración sin dominio, usa `-UseIpBasedDomains`; el script deriva nombres temporales de `nip.io` desde la IP pública. Esos nombres dependen de un servicio DNS de terceros y no son recomendables para producción.
- Una clave SSH pública y su clave privada correspondiente. La regla SSH del NSG queda limitada al CIDR que se indique.

El despliegue usa roles de identidad administrada para que la VM lea secretos de Key Vault y descargue imágenes de ACR; no habilita contraseñas de administrador en ACR. [Microsoft documenta este flujo para VMs](https://learn.microsoft.com/en-us/azure/container-registry/container-registry-authentication-managed-identity) y el acceso a secretos mediante RBAC de Key Vault en su [guía de RBAC](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide).

## Pasos

1. Inicia sesión y selecciona la suscripción:

   ```powershell
   az login
   az account set --subscription "<id-o-nombre-de-suscripcion>"
   ```

2. Ejecuta el instalador desde cualquier directorio. Los nombres de ACR y Key Vault deben ser únicos en Azure. Usa un CIDR preciso para SSH, por ejemplo `203.0.113.15/32`:

   ```powershell
   .\infra\azure\deploy.ps1 `
     -ResourceGroup "rg-deathdoku-prod" `
     -Location "spaincentral" `
     -AcrName "<acr-global-unico>" `
     -KeyVaultName "<keyvault-global-unico>" `
     -AdminUsername "azureuser" `
     -SshPublicKeyPath "$env:USERPROFILE\.ssh\id_ed25519.pub" `
     -SshPrivateKeyPath "$env:USERPROFILE\.ssh\id_ed25519" `
     -AdminSourceCidr "<tu-ip-publica>/32" `
     -ApiDomain "api.<tu-dominio>" `
     -AuthDomain "login.<tu-dominio>"
   ```

   Para una demostración sin dominio propio, reemplaza los dos últimos parámetros por `-UseIpBasedDomains`. Para publicar el cliente detrás del proxy de Vercel, agrega `-ClientApiBaseUrl "https://deathdoku-game.vercel.app/backend"` y `-KeycloakPublicBaseUrl "https://deathdoku-game.vercel.app/identity"`; conserva `ApiDomain` y `AuthDomain` para el proxy Caddy de Azure.

3. La primera ejecución crea recursos y muestra la IP estática. Con dominios propios, si los DNS A aún no apuntan a esa IP, el script se detendrá antes de compilar o publicar imágenes; crea ambos registros y vuelve a ejecutar el mismo comando. Con `-UseIpBasedDomains`, `nip.io` resuelve automáticamente los nombres temporales a esa IP.

4. El script habilita Azure VM Backup con la política diaria predeterminada (30 días de retención), construye las cinco imágenes en ACR, genera contraseñas criptográficas una sola vez, las guarda en Key Vault si aún no existen, copia la configuración al servidor y activa el servicio systemd para que la aplicación vuelva a arrancar después de reiniciar la VM. No sobrescribe secretos al actualizar. Azure Backup y sus snapshots generan cargos adicionales; usa `-SkipBackup` solo si tu organización ya protege la VM de otra forma. Microsoft describe la política diaria predeterminada en su [guía de Azure Backup para VMs](https://learn.microsoft.com/en-us/azure/backup/quick-backup-vm-cli).

5. Comprueba `https://api.<tu-dominio>/usuarios/health` y `https://login.<tu-dominio>/realms/hopedoku/.well-known/openid-configuration`. El primer inicio de Keycloak puede tardar unos minutos mientras inicializa su base de datos.

## Cliente Godot

El script crea `death-doku/export/azure/deathdoku.json` con las URLs públicas, sin credenciales. Desde `death-doku`, exporta el ejecutable Windows con la configuración al lado:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_windows.ps1 -DeploymentConfig export/azure/deathdoku.json
```

No publiques el archivo en el repositorio ni pongas tokens en él.

Los usuarios iniciales del realm de demostración reciben contraseñas aleatorias. Recupera solo las necesarias directamente desde Key Vault después del despliegue:

```powershell
az keyvault secret show --vault-name "<keyvault-global-unico>" --name keycloak-player-password --query value --output tsv
az keyvault secret show --vault-name "<keyvault-global-unico>" --name keycloak-admin-password --query value --output tsv
```

El usuario jugador exige enrolar TOTP durante el primer inicio. Cambia o reemplaza las cuentas iniciales antes de una apertura pública amplia. No compartas valores de Key Vault en capturas o logs.

## Operación

- Los datos persisten en volúmenes Docker sobre un disco de datos administrado separado del disco del sistema. Al eliminar la VM, Azure lo desconecta en vez de borrarlo. Azure VM Backup protege los discos diariamente; ensaya una restauración antes de guardar datos de usuarios reales. El disco persistente no reemplaza una copia de seguridad.
- La entrada pública se limita a TCP 80/443. Grafana, Prometheus, Eureka, Kafka, bases de datos y servicios internos no tienen puertos publicados. SSH solo acepta el CIDR suministrado.
- Para actualizar, vuelve a ejecutar el mismo `deploy.ps1`: construye tags nuevos, conserva secretos y datos, y aplica las imágenes nuevas. Revisa primero cambios de esquema o configuración que no sean compatibles hacia atrás.
- Los logs del sistema están disponibles con `sudo journalctl -u deathdoku.service`; los logs de contenedores con `sudo docker compose --project-name deathdoku --env-file /opt/deathdoku/.env.azure --env-file /opt/deathdoku/.env.secrets -f /opt/deathdoku/docker-compose.yml -f /opt/deathdoku/infra/azure/docker-compose.azure.yml logs`.

La VM usa [cloud-init para instalar Docker y Azure CLI al aprovisionarse](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init). Para operaciones reales, revisa costes y cuotas de la VM, ACR, Key Vault, IP pública, almacenamiento y transferencia antes de ejecutar el script.
