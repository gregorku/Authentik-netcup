#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"; source "$SCRIPT_DIR/lib/common.sh"; source "$SCRIPT_DIR/lib/filesystem.sh"; source "$SCRIPT_DIR/lib/docker.sh"; source "$SCRIPT_DIR/lib/sync.sh"; source "$SCRIPT_DIR/lib/init/directories.sh"; source "$SCRIPT_DIR/lib/init/networks.sh"
check_environment; require_docker_daemon
docker_container_running dockge || fail 'Dockge is not running; this project will not install it.'
init_directories; sync_stack; init_networks
[[ -f "$ENV_FILE" ]] || warn "Create $ENV_FILE from $ENV_EXAMPLE_FILE and set real values before deployment."
ok 'Initialization completed without starting services.'
