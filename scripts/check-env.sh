#!/usr/bin/env bash
set -Eeuo pipefail
ENV_FILE="${1:-/docker-data/stacks/authentik-netcup/.env}"
[[ -r "$ENV_FILE" ]] || { echo "Missing runtime .env: $ENV_FILE" >&2; exit 1; }
set -a; source "$ENV_FILE"; set +a
for key in COMPOSE_PROJECT_NAME DATA_DIR AUTHENTIK_HOST_IP AUTHENTIK_HTTP_PORT AUTHENTIK_VERSION POSTGRES_VERSION REDIS_VERSION AUTHENTIK_SECRET_KEY POSTGRES_PASSWORD POSTGRES_DB POSTGRES_USER; do
    [[ -n "${!key:-}" ]] || { echo "Required variable is empty: $key" >&2; exit 1; }
done
[[ "$COMPOSE_PROJECT_NAME" == authentik-netcup && "$DATA_DIR" == /docker-data/authentik-netcup ]] || { echo 'Unexpected project paths' >&2; exit 1; }
[[ "$AUTHENTIK_HOST_IP" == 10.10.10.100 && "$AUTHENTIK_HTTP_PORT" == 9000 ]] || { echo 'Backend must bind 10.10.10.100:9000' >&2; exit 1; }
[[ ${#POSTGRES_PASSWORD} -le 99 ]] || { echo 'POSTGRES_PASSWORD exceeds PostgreSQL limit' >&2; exit 1; }
for key in AUTHENTIK_VERSION POSTGRES_VERSION REDIS_VERSION AUTHENTIK_SECRET_KEY POSTGRES_PASSWORD; do
    [[ "${!key}" != REPLACE_WITH_* ]] || { echo "Replace placeholder: $key" >&2; exit 1; }
done
echo 'Runtime .env structure is valid.'
