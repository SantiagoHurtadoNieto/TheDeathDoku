#!/usr/bin/env bash
set -euo pipefail

ROOT=/opt/deathdoku
cd "$ROOT"
source "$ROOT/azure.conf"

az login --identity --allow-no-subscriptions --output none
"$ROOT/sync-secrets.sh"
for attempt in $(seq 1 20); do
  if az acr login --name "$ACR_NAME" --output none; then break; fi
  if [[ "$attempt" == 20 ]]; then echo 'Could not authenticate to Azure Container Registry.' >&2; exit 1; fi
  sleep 15
done

compose=(docker compose --project-name deathdoku --env-file "$ROOT/.env.azure" --env-file "$ROOT/.env.secrets" -f "$ROOT/docker-compose.yml" -f "$ROOT/infra/azure/docker-compose.azure.yml")
"${compose[@]}" config --quiet
"${compose[@]}" pull
"${compose[@]}" up -d --remove-orphans
