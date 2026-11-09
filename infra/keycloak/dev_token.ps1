<#
.SYNOPSIS
    Prepara la sesion de PowerShell con un token de desarrollo de DeathDoku.

.DESCRIPTION
    Pide un token con Direct Access Grant al cliente publico `hopedoku-test`
    (solo habilitado por docker-compose.dev.yml) para un usuario de prueba y
    deja el access token, el refresh token y el id de cliente SOLO en variables
    de entorno de esta sesion de PowerShell.

    No imprime tokens, contrasenas ni el contenido del .env. No escribe nada en
    disco. Godot los leera unicamente si se ejecuta desde el editor
    (OS.has_feature("editor")).

    Usalo con dot-sourcing para que las variables queden en tu sesion:

        cd C:\dev\TheDeathDoku
        . .\infra\keycloak\dev_token.ps1

.EXAMPLE
    . .\infra\keycloak\dev_token.ps1

.EXAMPLE
    . .\infra\keycloak\dev_token.ps1 -Username test-b
#>
[CmdletBinding()]
param(
    [string]$KeycloakBase = '',
    [string]$Realm = 'hopedoku',
    [string]$ClientId = 'hopedoku-test',
    [string]$Username = 'test-a',
    [string]$PasswordKey = ''
)

$ErrorActionPreference = 'Stop'

function Read-DotEnvFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 1) { continue }
        $name = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim()
        if ($value.Length -ge 2 -and (
                ($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $values[$name] = $value
    }
    return $values
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dotEnv = Read-DotEnvFile -Path (Join-Path $repoRoot '.env')

if ([string]::IsNullOrWhiteSpace($KeycloakBase)) {
    $KeycloakBase = if ($dotEnv.ContainsKey('KC_HOSTNAME') -and $dotEnv['KC_HOSTNAME']) {
        $dotEnv['KC_HOSTNAME']
    } else {
        [Environment]::GetEnvironmentVariable('KC_HOSTNAME', 'Process')
    }
}
if ([string]::IsNullOrWhiteSpace($KeycloakBase)) { $KeycloakBase = 'http://localhost:8180' }
$KeycloakBase = $KeycloakBase.TrimEnd('/')

# test-a -> KC_TEST_A_PASSWORD, test-admin -> KC_TEST_ADMIN_PASSWORD
if ([string]::IsNullOrWhiteSpace($PasswordKey)) {
    $suffix = ($Username -replace '^test-', '') -replace '-', '_'
    $PasswordKey = 'KC_TEST_{0}_PASSWORD' -f $suffix.ToUpperInvariant()
}

$password = if ($dotEnv.ContainsKey($PasswordKey) -and $dotEnv[$PasswordKey]) {
    $dotEnv[$PasswordKey]
} else {
    [Environment]::GetEnvironmentVariable($PasswordKey, 'Process')
}
if ([string]::IsNullOrWhiteSpace($password)) {
    throw "Falta $PasswordKey en el .env de la raiz o en el entorno."
}

$tokenUri = "$KeycloakBase/realms/$Realm/protocol/openid-connect/token"
$form = @{
    grant_type = 'password'
    client_id  = $ClientId
    username   = $Username
    password   = $password
    scope      = 'openid'
}

$response = $null
try {
    $response = Invoke-RestMethod -Method Post -Uri $tokenUri -Body $form `
        -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 20
} catch {
    $status = $null
    if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }
    $password = $null
    $form['password'] = $null
    if ($status) {
        throw "Keycloak rechazo la peticion de token (HTTP $status). Revisa que docker-compose.dev.yml este activo y que dev-setup.ps1 haya creado a $Username."
    }
    throw "No se pudo contactar con Keycloak en $KeycloakBase. Revisa que el contenedor este activo."
}

$password = $null
$form['password'] = $null

if ([string]::IsNullOrWhiteSpace($response.access_token)) {
    throw 'Keycloak devolvio una respuesta sin access_token.'
}

$expiresIn = [int]$response.expires_in
$expiresAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $expiresIn
$hasRefresh = -not [string]::IsNullOrWhiteSpace($response.refresh_token)

$env:DEATHDOKU_DEV_TOKEN = [string]$response.access_token
$env:DEATHDOKU_DEV_TOKEN_EXPIRES_AT = [string]$expiresAt
$env:DEATHDOKU_CLIENT_ID = $ClientId
if ($hasRefresh) {
    $env:DEATHDOKU_DEV_REFRESH_TOKEN = [string]$response.refresh_token
} else {
    Remove-Item Env:\DEATHDOKU_DEV_REFRESH_TOKEN -ErrorAction SilentlyContinue
}

$response = $null

Write-Host ("Sesion de desarrollo preparada: usuario '{0}', cliente '{1}', realm '{2}', caduca en {3} s, refresh token: {4}." -f `
        $Username, $ClientId, $Realm, $expiresIn, $(if ($hasRefresh) { 'si' } else { 'no' }))
Write-Host 'Variables de esta sesion: DEATHDOKU_DEV_TOKEN, DEATHDOKU_DEV_REFRESH_TOKEN, DEATHDOKU_DEV_TOKEN_EXPIRES_AT, DEATHDOKU_CLIENT_ID.'
Write-Host 'Abre el editor de Godot desde ESTA misma sesion; consulta README.dev-token.md.'
