#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"; source "$SCRIPT_DIR/lib/common.sh"; source "$SCRIPT_DIR/lib/docker-compose.sh"; source "$SCRIPT_DIR/lib/sync.sh"
case "${1:-}" in ''|--apply) ;; *) echo 'Usage: deploy.sh [--apply]' >&2; exit 2;; esac
check_environment; require_docker_daemon; sync_stack
"$SCRIPT_DIR/check-env.sh" "$ENV_FILE"; validate_compose; compose_pull
if [[ "${1:-}" == --apply ]]; then compose_up; else info 'Validated and pulled only; use --apply to start/update services.'; fi
