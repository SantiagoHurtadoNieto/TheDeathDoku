param(
    [Parameter(Mandatory = $true)] [string] $ResourceGroup,
    [Parameter(Mandatory = $true)] [string] $Location,
    [Parameter(Mandatory = $true)] [string] $AcrName,
    [Parameter(Mandatory = $true)] [string] $KeyVaultName,
    [Parameter(Mandatory = $true)] [string] $AdminUsername,
    [Parameter(Mandatory = $true)] [string] $SshPublicKeyPath,
    [Parameter(Mandatory = $true)] [string] $SshPrivateKeyPath,
    [Parameter(Mandatory = $true)] [string] $AdminSourceCidr,
    [Parameter(Mandatory = $true)] [string] $ApiDomain,
    [Parameter(Mandatory = $true)] [string] $AuthDomain,
    [string] $VmSize = 'Standard_D4s_v5',
    [switch] $SkipBackup
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Stage = Join-Path $env:TEMP ("deathdoku-azure-{0}" -f [guid]::NewGuid().ToString('N'))

function Invoke-Az {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Arguments)
    & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed (exit $LASTEXITCODE): az $($Arguments -join ' ')"
    }
}

function New-RandomSecret {
    $bytes = [byte[]]::new(32)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [Convert]::ToHexString($bytes)
}

function Ensure-KeyVaultSecret {
    param([string] $Name)
    & az keyvault secret show --vault-name $KeyVaultName --name $Name --query id --output tsv 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }

    $tempSecret = Join-Path $Stage ("secret-{0}.txt" -f $Name)
    $secretValue = New-RandomSecret
    [System.IO.File]::WriteAllText($tempSecret, $secretValue, [System.Text.UTF8Encoding]::new($false))
    Invoke-Az keyvault secret set --vault-name $KeyVaultName --name $Name --file $tempSecret --output none
    Remove-Item -LiteralPath $tempSecret -Force
}

function Invoke-Ssh {
    param([string] $Target, [string] $RemoteCommand)
    & ssh -i $SshPrivateKeyPath -o StrictHostKeyChecking=accept-new $Target $RemoteCommand
    if ($LASTEXITCODE -ne 0) { throw "SSH command failed on $Target (exit $LASTEXITCODE)." }
}

function Copy-RemoteFile {
    param([string] $Source, [string] $Target)
    & scp -i $SshPrivateKeyPath -o StrictHostKeyChecking=accept-new $Source $Target
    if ($LASTEXITCODE -ne 0) { throw "Could not copy deployment file: $Source" }
}

function Invoke-AcrBuild {
    param([string] $ImageName, [string] $Tag, [string] $Dockerfile, [string] $Context)
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        & az acr build --registry $AcrName --image "$ImageName`:$Tag" --file $Dockerfile $Context --output none
        if ($LASTEXITCODE -eq 0) { return }
        if ($attempt -eq 10) { throw "ACR build failed for $ImageName after 10 attempts." }
        Start-Sleep -Seconds 15
    }
}

foreach ($tool in @('az', 'ssh', 'scp')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $tool. Install Azure CLI and Windows OpenSSH Client."
    }
}
foreach ($path in @($SshPublicKeyPath, $SshPrivateKeyPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "SSH key file not found: $path" }
}
if ($AdminUsername -notmatch '^[a-z_][a-z0-9_-]{0,31}$') { throw 'AdminUsername must be a valid Linux account name.' }
if ($ApiDomain -notmatch '^[a-zA-Z0-9.-]+$' -or $AuthDomain -notmatch '^[a-zA-Z0-9.-]+$') {
    throw 'API and auth domains must be hostnames only, without scheme or path.'
}
if ($ApiDomain -eq $AuthDomain) { throw 'API domain and auth domain must be different hostnames.' }
if ($AcrName -notmatch '^[a-z0-9]{5,50}$') { throw 'AcrName must contain 5-50 lowercase letters or digits.' }
if ($KeyVaultName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$') { throw 'KeyVaultName must be 3-24 letters, digits, or hyphens, and start/end with a letter or digit.' }
if ($AdminSourceCidr -notmatch '^.+/(?:[1-9]|[12][0-9]|3[0-2])$') { throw 'AdminSourceCidr must include a usable IPv4 prefix from /1 to /32; do not expose SSH to the entire internet.' }

$azVersionText = (& az version --query '"azure-cli"' --output tsv 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or [version]$azVersionText -lt [version]'2.73.0') {
    throw 'Azure CLI 2.73.0 or newer is required for Azure Backup with this Trusted Launch VM.'
}

New-Item -ItemType Directory -Path $Stage -Force | Out-Null
try {
    $subscriptionId = (& az account show --query id --output tsv 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($subscriptionId)) {
        throw 'Run az login and select the Azure subscription before deployment.'
    }

    $account = (& az account show --output json 2>$null | ConvertFrom-Json)
    $deployerPrincipalType = if ($account.user.type -eq 'user') { 'User' } else { 'ServicePrincipal' }
    if ($deployerPrincipalType -eq 'User') {
        $deployerPrincipalId = (& az ad signed-in-user show --query id --output tsv 2>$null).Trim()
    } else {
        $deployerPrincipalId = (& az ad sp show --id $account.user.name --query id --output tsv 2>$null).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($deployerPrincipalId)) {
        throw 'Could not resolve the signed-in Azure identity object ID for scoped ACR and Key Vault roles.'
    }

    Invoke-Az group create --name $ResourceGroup --location $Location --output none
    $template = Join-Path $PSScriptRoot 'main.bicep'
    $sshPublicKey = (Get-Content -LiteralPath $SshPublicKeyPath -Raw).Trim()
    $deploymentJson = & az deployment group create --resource-group $ResourceGroup --template-file $template --parameters "adminUsername=$AdminUsername" "sshPublicKey=$sshPublicKey" "deployerPrincipalId=$deployerPrincipalId" "deployerPrincipalType=$deployerPrincipalType" "adminSourceCidr=$AdminSourceCidr" "acrName=$AcrName" "keyVaultName=$KeyVaultName" "vmSize=$VmSize" --output json
    if ($LASTEXITCODE -ne 0) { throw 'Azure infrastructure deployment failed.' }
    $deployment = $deploymentJson | ConvertFrom-Json
    $outputs = $deployment.properties.outputs
    $publicIp = [string] $outputs.publicIpAddress.value
    $acrLoginServer = [string] $outputs.acrLoginServer.value
    if ([string]::IsNullOrWhiteSpace($publicIp) -or [string]::IsNullOrWhiteSpace($acrLoginServer)) {
        throw 'Deployment completed but expected outputs were missing.'
    }

    Write-Host "Azure VM public IP: $publicIp"
    foreach ($domain in @($ApiDomain, $AuthDomain)) {
        $addresses = @()
        try { $addresses = @(Resolve-DnsName -Name $domain -Type A -ErrorAction Stop | ForEach-Object IPAddress) } catch {}
        if ($addresses -notcontains $publicIp) {
            throw "Set an A record for $domain to $publicIp, wait for DNS propagation, then rerun this script."
        }
    }

    if (-not $SkipBackup) {
        $backupVaultName = 'deathdoku-backup'
        Invoke-Az backup vault create --resource-group $ResourceGroup --name $backupVaultName --location $Location --output none
        $backupState = (& az backup protection check-vm --resource-group $ResourceGroup --vm 'deathdoku-prod-vm' --output json 2>$null) -join ''
        if ($LASTEXITCODE -ne 0) { throw 'Could not check the Azure VM backup state.' }
        if ([string]::IsNullOrWhiteSpace($backupState) -or $backupState.Trim() -eq 'null') {
            Invoke-Az backup protection enable-for-vm --resource-group $ResourceGroup --vault-name $backupVaultName --vm 'deathdoku-prod-vm' --policy-name 'DefaultPolicy' --output none
        }
    }

    $imageTag = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $images = @(
        @{ Name = 'deathdoku-eureka'; Context = 'eureka-server'; Dockerfile = 'Dockerfile' },
        @{ Name = 'deathdoku-users'; Context = 'users_service'; Dockerfile = 'Dockerfile' },
        @{ Name = 'deathdoku-cases'; Context = 'cases-service'; Dockerfile = 'Dockerfile' },
        @{ Name = 'deathdoku-matches'; Context = 'partidas-service'; Dockerfile = 'Dockerfile' },
        @{ Name = 'deathdoku-gateway'; Context = 'apigateway'; Dockerfile = 'Dockerfile' }
    )
    foreach ($image in $images) {
        $context = Join-Path $RepoRoot $image.Context
        Invoke-AcrBuild $image.Name $imageTag $image.Dockerfile $context
    }

    $keyVaultAccessReady = $false
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        & az keyvault secret list --vault-name $KeyVaultName --maxresults 1 --query '[0].id' --output tsv 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $keyVaultAccessReady = $true; break }
        Start-Sleep -Seconds 10
    }
    if (-not $keyVaultAccessReady) { throw 'Key Vault role assignment is not active yet; rerun the deployment after a short wait.' }
    foreach ($secretName in @(
        'gateway-secret', 'internal-api-token', 'metrics-scrape-password', 'postgres-password',
        'mongo-password', 'keycloak-db-password', 'keycloak-bootstrap-admin-password',
        'keycloak-player-password', 'keycloak-admin-password', 'grafana-admin-password'
    )) { Ensure-KeyVaultSecret $secretName }

    $remote = "$AdminUsername@$publicIp"
    $remoteRoot = '/opt/deathdoku'
    Invoke-Ssh $remote "sudo mkdir -p $remoteRoot/infra/azure $remoteRoot/infra/keycloak $remoteRoot/infra/observability/prometheus $remoteRoot/infra/observability/grafana && sudo chown -R ${AdminUsername}:${AdminUsername} $remoteRoot"

    $envText = @(
        "API_DOMAIN=$ApiDomain",
        "AUTH_DOMAIN=$AuthDomain",
        "ACR_NAME=$AcrName",
        "ACR_LOGIN_SERVER=$acrLoginServer",
        "KEY_VAULT_NAME=$KeyVaultName",
        "IMAGE_TAG=$imageTag",
        'POSTGRES_DB=usuariosdb',
        'POSTGRES_USER=usuarios',
        'MONGO_USERNAME=root',
        'METRICS_SCRAPE_PASSWORD_FILE=./.secrets/metrics_scrape_password',
        'GRAFANA_ADMIN_USER=admin',
        'KC_HOSTNAME=https://'+$AuthDomain,
        'KC_BOOTSTRAP_ADMIN_USERNAME=kcadmin',
        'KEYCLOAK_ISSUER_URI=https://'+$AuthDomain+'/realms/hopedoku',
        'KEYCLOAK_JWKS_URI=http://keycloak:8080/realms/hopedoku/protocol/openid-connect/certs',
        'KEYCLOAK_AUDIENCE=hopedoku-gateway',
        'KEYCLOAK_ALLOWED_AZP=hopedoku-godot',
        'EUREKA_SERVER_URL=http://eureka-server:8762/eureka/',
        'EUREKA_REGISTRY_FETCH_INTERVAL_SECONDS=30',
        'EUREKA_LEASE_RENEWAL_INTERVAL_SECONDS=30',
        'LOADBALANCER_CACHE_TTL=30s',
        'KAFKA_BOOTSTRAP_SERVERS=kafka:9092'
    ) -join "`n"
    $envPath = Join-Path $Stage '.env.azure'
    [System.IO.File]::WriteAllText($envPath, $envText + "`n", [System.Text.UTF8Encoding]::new($false))

    $fileMap = @(
        @{ Source = (Join-Path $RepoRoot 'docker-compose.yml'); Target = "${remote}:$remoteRoot/docker-compose.yml" },
        @{ Source = (Join-Path $RepoRoot 'infra\kafka.yml'); Target = "${remote}:$remoteRoot/infra/kafka.yml" },
        @{ Source = (Join-Path $RepoRoot 'infra\keycloak\docker-compose.keycloak.yml'); Target = "${remote}:$remoteRoot/infra/keycloak/docker-compose.keycloak.yml" },
        @{ Source = (Join-Path $RepoRoot 'infra\keycloak\realm-hopedoku.json'); Target = "${remote}:$remoteRoot/infra/keycloak/realm-hopedoku.json" },
        @{ Source = (Join-Path $RepoRoot 'infra\observability\prometheus\prometheus.yml'); Target = "${remote}:$remoteRoot/infra/observability/prometheus/prometheus.yml" },
        @{ Source = (Join-Path $RepoRoot 'infra\observability\prometheus\alerts.yml'); Target = "${remote}:$remoteRoot/infra/observability/prometheus/alerts.yml" },
        @{ Source = (Join-Path $RepoRoot 'infra\azure\docker-compose.azure.yml'); Target = "${remote}:$remoteRoot/infra/azure/docker-compose.azure.yml" },
        @{ Source = (Join-Path $RepoRoot 'infra\azure\Caddyfile'); Target = "${remote}:$remoteRoot/infra/azure/Caddyfile" },
        @{ Source = (Join-Path $RepoRoot 'infra\azure\sync-secrets.sh'); Target = "${remote}:$remoteRoot/sync-secrets.sh" },
        @{ Source = (Join-Path $RepoRoot 'infra\azure\deploy-compose.sh'); Target = "${remote}:$remoteRoot/deploy-compose.sh" },
        @{ Source = $envPath; Target = "${remote}:$remoteRoot/.env.azure" }
    )
    foreach ($file in $fileMap) { Copy-RemoteFile $file.Source $file.Target }

    $remoteService = Join-Path $RepoRoot 'infra\azure\deathdoku.service'
    Copy-RemoteFile $remoteService "${remote}:$remoteRoot/deathdoku.service"
    & scp -r -i $SshPrivateKeyPath -o StrictHostKeyChecking=accept-new (Join-Path $RepoRoot 'infra\observability\grafana\provisioning') (Join-Path $RepoRoot 'infra\observability\grafana\dashboards') "${remote}:$remoteRoot/infra/observability/grafana/"
    if ($LASTEXITCODE -ne 0) { throw 'Could not copy Grafana provisioning files.' }
    Invoke-Ssh $remote "sudo chmod 700 $remoteRoot/sync-secrets.sh $remoteRoot/deploy-compose.sh; sudo install -m 0750 $remoteRoot/sync-secrets.sh /usr/local/sbin/deathdoku-sync-secrets; sudo install -m 0750 $remoteRoot/deploy-compose.sh /usr/local/sbin/deathdoku-deploy-compose; sudo install -m 0644 $remoteRoot/deathdoku.service /etc/systemd/system/deathdoku.service; sudo tee $remoteRoot/azure.conf >/dev/null <<'EOF'`nACR_NAME=$AcrName`nKEY_VAULT_NAME=$KeyVaultName`nEOF`nsudo chmod 600 $remoteRoot/azure.conf; sudo systemctl daemon-reload; sudo systemctl enable deathdoku.service; sudo /usr/local/sbin/deathdoku-deploy-compose"

    $clientConfig = [ordered]@{
        api_base = "https://$ApiDomain"
        keycloak_base = "https://$AuthDomain"
        realm = 'hopedoku'
        client_id = 'hopedoku-godot'
        timeout_seconds = 15
        refresh_margin_seconds = 60
    } | ConvertTo-Json
    $clientConfigPath = Join-Path $RepoRoot 'death-doku\export\azure\deathdoku.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $clientConfigPath) -Force | Out-Null
    [System.IO.File]::WriteAllText($clientConfigPath, $clientConfig + "`n", [System.Text.UTF8Encoding]::new($false))

    Write-Host "Deployment is up. API: https://$ApiDomain; Keycloak: https://$AuthDomain"
    Write-Host "Copy $clientConfigPath beside the exported Windows executable."
    Write-Host 'Initial Keycloak account passwords were generated in Key Vault; retrieve them there before onboarding the seeded accounts.'
    if (-not $SkipBackup) { Write-Host 'Azure VM Backup is enabled with the vault daily policy (30-day retention); backup storage and snapshots add recurring cost.' }
    Write-Host "VM: $AdminUsername@$publicIp (SSH is restricted to $AdminSourceCidr)"
}
finally {
    if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
}
