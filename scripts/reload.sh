#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/config.sh"; source "$SCRIPT_DIR/lib/docker-compose.sh"
[[ "${1:-}" == --apply ]] || { echo 'Usage: reload.sh --apply (recreates services and can interrupt sessions)' >&2; exit 2; }
"$SCRIPT_DIR/deploy.sh" --apply
compose_cmd up -d --force-recreate server worker
