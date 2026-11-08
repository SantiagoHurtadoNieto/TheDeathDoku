#requires -Version 5.1
<#
.SYNOPSIS
Creates the local-only Keycloak fixtures used by the Bruno regression collection.

.DESCRIPTION
Idempotently creates the public client "hopedoku-test" (Direct Access Grants) and the
users test-a, test-b and test-admin in the ACTIVE hopedoku realm, using the Keycloak
Admin REST API. This is a DEVELOPMENT-ONLY helper: it refuses to run against a
non-local Keycloak URL unless -AllowRemote is passed explicitly.

It never prints passwords or tokens and it does not modify realm-hopedoku.json.

.PARAMETER Clean
Deletes the test client and the three test users. Does not touch the realm, other
users, volumes or regression files.

.PARAMETER AllowRemote
Bypasses the localhost-only guard. Use only with a disposable environment.

.PARAMETER NoBrunoEnv
Do not write the three test passwords to regression/.env.
#>
[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$AllowRemote,
    [switch]$NoBrunoEnv
)

$ErrorActionPreference = 'Stop'

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:Realm = 'hopedoku'
$script:TestClientId = 'hopedoku-test'
$script:TestUsers = @(
    [pscustomobject]@{ Username = 'test-a'; Email = 'test-a@example.test'; Roles = @('USER'); PasswordKey = 'KC_TEST_A_PASSWORD' },
    [pscustomobject]@{ Username = 'test-b'; Email = 'test-b@example.test'; Roles = @('USER'); PasswordKey = 'KC_TEST_B_PASSWORD' },
    [pscustomobject]@{ Username = 'test-admin'; Email = 'test-admin@example.test'; Roles = @('USER', 'ADMIN'); PasswordKey = 'KC_TEST_ADMIN_PASSWORD' }
)

function Read-DotEnvFile {
    param([Parameter(Mandatory)][string]$Path)

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 1) { continue }
        $key = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim()
        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $values[$key] = $value
    }
    return $values
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][hashtable]$DotEnv
    )

    $fromProcess = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($fromProcess)) { return $fromProcess }
    if ($DotEnv.ContainsKey($Name)) { return [string]$DotEnv[$Name] }
    return $null
}

function Get-HttpStatusCode {
    param($ErrorRecord)

    try {
        if ($null -ne $ErrorRecord.Exception.Response) {
            return [int]$ErrorRecord.Exception.Response.StatusCode
        }
    } catch {
        return $null
    }
    return $null
}

function Invoke-KcAdmin {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body = $null
    )

    $parameters = @{
        Method     = $Method
        Uri        = "$script:KcBaseUrl/admin/realms/$script:Realm$Path"
        Headers    = $script:AdminHeaders
        TimeoutSec = 30
    }
    if ($null -ne $Body) {
        $parameters['ContentType'] = 'application/json'
        $parameters['Body'] = (ConvertTo-Json -InputObject $Body -Depth 10 -Compress)
    }
    return Invoke-RestMethod @parameters
}

function Get-KcClient {
    $encoded = [Uri]::EscapeDataString($script:TestClientId)
    $clients = Invoke-KcAdmin -Method GET -Path "/clients?clientId=$encoded"
    return @($clients) | Select-Object -First 1
}

function Get-KcUser {
    param([Parameter(Mandatory)][string]$Username)

    $encoded = [Uri]::EscapeDataString($Username)
    $users = Invoke-KcAdmin -Method GET -Path "/users?username=$encoded&exact=true"
    return @($users) | Select-Object -First 1
}

function Get-KcRealmRole {
    param([Parameter(Mandatory)][string]$Name)

    return Invoke-KcAdmin -Method GET -Path "/roles/$([Uri]::EscapeDataString($Name))"
}

function Set-KcUserPassword {
    param(
        [Parameter(Mandatory)]$User,
        [Parameter(Mandatory)][string]$Password
    )

    $payload = @{
        type      = 'password'
        value     = $Password
        temporary = $false
    }
    Invoke-KcAdmin -Method PUT -Path "/users/$($User.id)/reset-password" -Body $payload | Out-Null
}

function Set-KcUserRealmRoles {
    param(
        [Parameter(Mandatory)]$User,
        [Parameter(Mandatory)][string[]]$DesiredRoles,
        [Parameter(Mandatory)][hashtable]$RoleRepresentations
    )

    $current = @(Invoke-KcAdmin -Method GET -Path "/users/$($User.id)/role-mappings/realm")
    $managed = @('USER', 'ADMIN')

    $toAdd = @()
    foreach ($roleName in $DesiredRoles) {
        if (-not ($current | Where-Object { $_.name -eq $roleName })) {
            $toAdd += $RoleRepresentations[$roleName]
        }
    }
    if ($toAdd.Count -gt 0) {
        Invoke-KcAdmin -Method POST -Path "/users/$($User.id)/role-mappings/realm" -Body $toAdd | Out-Null
    }

    $toRemove = @($current | Where-Object { $managed -contains $_.name -and $DesiredRoles -notcontains $_.name })
    if ($toRemove.Count -gt 0) {
        Invoke-KcAdmin -Method DELETE -Path "/users/$($User.id)/role-mappings/realm" -Body $toRemove | Out-Null
    }
}

function Test-KcPasswordGrant {
    param(
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$Password
    )

    $form = @{
        grant_type = 'password'
        client_id  = $script:TestClientId
        username   = $Username
        password   = $Password
    }
    try {
        $response = Invoke-RestMethod -Method Post -Uri $script:RealmTokenUri -Body $form `
            -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 30
    } catch {
        $status = Get-HttpStatusCode $_
        $detail = 'sin detalle'
        try {
            if ($null -ne $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
        } catch { }
        throw "El usuario '$Username' no pudo obtener token (HTTP $status). Revisa las acciones requeridas. Detalle: $detail"
    }
    if ([string]::IsNullOrWhiteSpace($response.access_token)) {
        throw "El usuario '$Username' obtuvo una respuesta sin access_token."
    }
}

function Write-BrunoEnv {
    param([Parameter(Mandatory)][hashtable]$Passwords)

    $path = Join-Path $script:RepoRoot 'regression/.env'
    $ignored = $false
    try {
        & git -c "safe.directory=$script:RepoRoot" -C $script:RepoRoot check-ignore --quiet 'regression/.env' 2>$null
        $ignored = ($LASTEXITCODE -eq 0)
    } catch {
        $ignored = $false
    }

    if (-not $ignored) {
        Write-Warning 'regression/.env no está ignorado por Git; no se escriben credenciales.'
        return
    }

    $lines = @()
    if (Test-Path -LiteralPath $path) { $lines = @(Get-Content -LiteralPath $path) }

    $existing = @{}
    foreach ($line in $lines) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $existing[$matches[1]] = $matches[2]
        }
    }

    $toAdd = @()
    foreach ($key in @('KC_TEST_A_PASSWORD', 'KC_TEST_B_PASSWORD', 'KC_TEST_ADMIN_PASSWORD')) {
        if ($existing.ContainsKey($key)) {
            if ($existing[$key] -ne $Passwords[$key]) {
                Write-Warning "$key ya existe en regression/.env con otro valor; no se sobrescribe. Debe coincidir con el .env de la raíz."
            }
        } else {
            $toAdd += "$key=$($Passwords[$key])"
        }
    }

    if ($toAdd.Count -eq 0) {
        Write-Host 'regression/.env ya contiene las tres claves de prueba.'
        return
    }

    if ($lines.Count -gt 0 -and $lines[-1] -ne '') { $lines += '' }
    $lines += '# Dev-only credentials for the Bruno regression (gitignored).'
    $lines += $toAdd
    Set-Content -LiteralPath $path -Value $lines -Encoding ASCII
    Write-Host 'regression/.env actualizado con las claves que faltaban (sin mostrar valores).'
}

# --- configuration -----------------------------------------------------------------

$dotEnv = Read-DotEnvFile -Path (Join-Path $script:RepoRoot '.env')
$script:KcBaseUrl = (Get-ConfigValue -Name 'KC_HOSTNAME' -DotEnv $dotEnv)
if ([string]::IsNullOrWhiteSpace($script:KcBaseUrl)) { $script:KcBaseUrl = 'http://localhost:8180' }
$script:KcBaseUrl = $script:KcBaseUrl.TrimEnd('/')

try {
    $kcUri = [Uri]$script:KcBaseUrl
} catch {
    throw "KC_HOSTNAME no es una URL válida."
}
if ($kcUri.Scheme -notin @('http', 'https')) {
    throw "KC_HOSTNAME debe usar http o https."
}
$localHosts = @('localhost', '127.0.0.1', '::1')
if ($localHosts -notcontains $kcUri.Host -and -not $AllowRemote) {
    throw "KC_HOSTNAME apunta a '$($kcUri.Host)'. Este script es solo para desarrollo local; usa -AllowRemote para forzar."
}

$adminUsername = Get-ConfigValue -Name 'KC_BOOTSTRAP_ADMIN_USERNAME' -DotEnv $dotEnv
$adminPassword = Get-ConfigValue -Name 'KC_BOOTSTRAP_ADMIN_PASSWORD' -DotEnv $dotEnv
if ([string]::IsNullOrWhiteSpace($adminUsername) -or [string]::IsNullOrWhiteSpace($adminPassword)) {
    throw 'Faltan KC_BOOTSTRAP_ADMIN_USERNAME o KC_BOOTSTRAP_ADMIN_PASSWORD en .env o en el entorno.'
}

$passwords = @{}
foreach ($user in $script:TestUsers) {
    $value = Get-ConfigValue -Name $user.PasswordKey -DotEnv $dotEnv
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Falta $($user.PasswordKey) en .env o en el entorno."
    }
    $passwords[$user.PasswordKey] = $value
}

$script:TokenUri = "$script:KcBaseUrl/realms/master/protocol/openid-connect/token"
$script:RealmTokenUri = "$script:KcBaseUrl/realms/$script:Realm/protocol/openid-connect/token"

Write-Host "Keycloak: $script:KcBaseUrl (realm $script:Realm)"

# --- admin token -------------------------------------------------------------------

$adminForm = @{
    grant_type = 'password'
    client_id  = 'admin-cli'
    username   = $adminUsername
    password   = $adminPassword
}
try {
    $adminTokenResponse = Invoke-RestMethod -Method Post -Uri $script:TokenUri -Body $adminForm `
        -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 30
} catch {
    $status = Get-HttpStatusCode $_
    throw "No se pudo autenticar como administrador (HTTP $status). Revisa KC_BOOTSTRAP_ADMIN_* y que admin-cli permita Direct Access Grants."
}
if ([string]::IsNullOrWhiteSpace($adminTokenResponse.access_token)) {
    throw 'La respuesta de administración no incluyó access_token.'
}
$script:AdminHeaders = @{ Authorization = "Bearer $($adminTokenResponse.access_token)" }
$adminTokenResponse = $null

# --- clean mode --------------------------------------------------------------------

if ($Clean) {
    $client = Get-KcClient
    if ($client) {
        Invoke-KcAdmin -Method DELETE -Path "/clients/$($client.id)" | Out-Null
        Write-Host "Cliente $script:TestClientId eliminado."
    } else {
        Write-Host "Cliente $script:TestClientId no existía."
    }

    foreach ($user in $script:TestUsers) {
        $existingUser = Get-KcUser -Username $user.Username
        if ($existingUser) {
            Invoke-KcAdmin -Method DELETE -Path "/users/$($existingUser.id)" | Out-Null
            Write-Host "Usuario $($user.Username) eliminado."
        } else {
            Write-Host "Usuario $($user.Username) no existía."
        }
    }

    Write-Host 'Limpieza terminada. El realm, jugador1/admin1 y los volúmenes no se tocaron.'
    return
}

# --- client ------------------------------------------------------------------------

$clientRepresentation = @{
    clientId                   = $script:TestClientId
    name                       = 'DeathDoku regression (dev only)'
    enabled                    = $true
    protocol                   = 'openid-connect'
    publicClient               = $true
    directAccessGrantsEnabled  = $true
    standardFlowEnabled        = $false
    implicitFlowEnabled        = $false
    serviceAccountsEnabled     = $false
    redirectUris               = @()
    webOrigins                 = @()
    defaultClientScopes        = @('basic', 'roles', 'profile', 'email')
}

$client = Get-KcClient
if ($client) {
    Invoke-KcAdmin -Method PUT -Path "/clients/$($client.id)" -Body $clientRepresentation | Out-Null
    Write-Host "Cliente $script:TestClientId actualizado."
} else {
    Invoke-KcAdmin -Method POST -Path '/clients' -Body $clientRepresentation | Out-Null
    $client = Get-KcClient
    if (-not $client) { throw "No se pudo crear el cliente $script:TestClientId." }
    Write-Host "Cliente $script:TestClientId creado."
}

# --- users -------------------------------------------------------------------------

$roleRepresentations = @{
    USER  = Get-KcRealmRole -Name 'USER'
    ADMIN = Get-KcRealmRole -Name 'ADMIN'
}

foreach ($user in $script:TestUsers) {
    $password = $passwords[$user.PasswordKey]
    $existingUser = Get-KcUser -Username $user.Username

    if (-not $existingUser) {
        $newUser = @{
            username      = $user.Username
            enabled       = $true
            emailVerified = $true
            email         = $user.Email
        }
        Invoke-KcAdmin -Method POST -Path '/users' -Body $newUser | Out-Null
        $existingUser = Get-KcUser -Username $user.Username
        if (-not $existingUser) { throw "No se pudo crear el usuario $($user.Username)." }
        Write-Host "Usuario $($user.Username) creado."
    } else {
        Write-Host "Usuario $($user.Username) ya existía."
    }

    # Keycloak copies CONFIGURE_TOTP (defaultAction=true) at creation time. A later
    # update with an empty requiredActions array is what removes it.
    Invoke-KcAdmin -Method PUT -Path "/users/$($existingUser.id)" -Body @{ requiredActions = @() } | Out-Null
    Set-KcUserPassword -User $existingUser -Password $password
    Set-KcUserRealmRoles -User $existingUser -DesiredRoles $user.Roles -RoleRepresentations $roleRepresentations
    Test-KcPasswordGrant -Username $user.Username -Password $password

    Write-Host "Usuario $($user.Username) listo (roles: $($user.Roles -join ', '))."
}

if (-not $NoBrunoEnv) {
    Write-BrunoEnv -Passwords $passwords
}

Write-Host 'Listo. Este cliente y estos usuarios son solo para desarrollo local.'
