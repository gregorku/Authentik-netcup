#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; repo="$(cd "$SCRIPT_DIR/.." && pwd)"; stack=/docker-data/stacks/authentik-netcup
find "$repo/scripts" -type f -name '*.sh' -exec bash -n {} +
grep -Fxq 'AUTHENTIK_HOST_IP=10.10.10.100' "$repo/.env.example"
grep -q 'AUTHENTIK_HTTP_PORT=9000' "$repo/.env.example"
! rg -q '5432:|6379:' "$repo/compose"
rg -q 'AUTHENTIK_HOST_IP.*AUTHENTIK_HTTP_PORT.*9000' "$repo/compose/10-authentik.yml"
rg -q 'DEPLOY_ITEMS=\(compose.yml compose configs .env.example\)' "$repo/scripts/config.sh"
if [[ -r "$stack/.env" ]]; then
    "$SCRIPT_DIR/check-env.sh" "$stack/.env"
    if command -v docker >/dev/null; then docker compose --env-file "$stack/.env" -f "$repo/compose.yml" config -q; fi
else
    echo 'SKIP runtime/Compose validation: target runtime .env is unavailable.'
fi
echo 'Static checks passed. Firewall, source-IP and running-service checks require the target container and were not run.'
