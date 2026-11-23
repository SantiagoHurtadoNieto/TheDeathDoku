#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/deathdoku
# shellcheck disable=SC1091
source "$ROOT/azure.conf"

umask 077
mkdir -p "$ROOT/.secrets"
az login --identity --allow-no-subscriptions --output none

fetch_secret() {
  local name="$1"
  local value=''
  for attempt in $(seq 1 30); do
    value="$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$name" --query value --output tsv 2>/dev/null || true)"
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
    sleep 5
  done
  echo "Could not read required Key Vault secret: $name" >&2
  return 1
}

secrets_file="$ROOT/.env.secrets.tmp"
secret_pairs=(
  'gateway-secret:GATEWAY_SECRET'
  'internal-api-token:INTERNAL_API_TOKEN'
  'metrics-scrape-password:METRICS_SCRAPE_PASSWORD'
  'postgres-password:POSTGRES_PASSWORD'
  'mongo-password:MONGO_PASSWORD'
  'keycloak-db-password:KEYCLOAK_DB_PASSWORD'
  'keycloak-bootstrap-admin-password:KC_BOOTSTRAP_ADMIN_PASSWORD'
  'keycloak-player-password:KC_JUGADOR1_PASSWORD'
  'keycloak-admin-password:KC_ADMIN1_PASSWORD'
  'grafana-admin-password:GRAFANA_ADMIN_PASSWORD'
)

: > "$secrets_file"
for pair in "${secret_pairs[@]}"; do
  vault_name="${pair%%:*}"
  env_name="${pair#*:}"
  secret_value="$(fetch_secret "$vault_name")"
  printf '%s=%s\n' "$env_name" "$secret_value" >> "$secrets_file"
  if [[ "$env_name" == 'METRICS_SCRAPE_PASSWORD' ]]; then
    printf '%s' "$secret_value" > "$ROOT/.secrets/metrics_scrape_password"
  fi
done
mv "$secrets_file" "$ROOT/.env.secrets"
chmod 600 "$ROOT/.env.secrets" "$ROOT/.secrets/metrics_scrape_password"
