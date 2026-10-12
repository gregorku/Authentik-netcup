#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/deploy.sh
#
# Description:
#   Deploy Monitoring-netcup services.
#
# Responsibilities:
#   - Verify deployment environment
#   - Deploy Dockge
#   - Deploy Monitoring-netcup Docker Compose stack
#   - Print deployment summary
#
###############################################################################

set -Eeuo pipefail

# Sync is deliberately restricted to individual repository-managed items.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; stack=/docker-data/stacks/authentik-netcup
[[ -r "$stack/.env" ]] || { echo "Missing $stack/.env (copy .env.example and generate secrets)." >&2; exit 1; }
"$repo/scripts/check-env.sh" "$stack/.env"
for item in compose.yml compose configs .env.example; do rsync -a --delete "$repo/$item" "$stack/"; done
docker compose --env-file "$stack/.env" -f "$stack/compose.yml" config -q
docker compose --env-file "$stack/.env" -f "$stack/compose.yml" pull
if [[ "${1:-}" == --apply ]]; then docker compose --env-file "$stack/.env" -f "$stack/compose.yml" up -d; else echo 'Validated and pulled. Re-run with --apply to start or change services.'; fi
exit 0

###############################################################################
# Directories
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Configuration
###############################################################################

source "${SCRIPT_DIR}/config.sh"

###############################################################################
# Core libraries
###############################################################################

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/logging.sh"

###############################################################################
# Docker Compose library
###############################################################################

source "${SCRIPT_DIR}/lib/docker-compose.sh"

###############################################################################
# Checks
###############################################################################

source "${SCRIPT_DIR}/lib/checks/load.sh"

###############################################################################
# Environment
###############################################################################

source "${SCRIPT_DIR}/lib/env/load.sh"

###############################################################################
# Deployment modules
###############################################################################

source "${SCRIPT_DIR}/lib/deploy/stack.sh"
source "${SCRIPT_DIR}/lib/deploy/verify.sh"
source "${SCRIPT_DIR}/lib/deploy/check-env.sh"
source "${SCRIPT_DIR}/lib/deploy/dockge.sh"
source "${SCRIPT_DIR}/lib/deploy/wait.sh"
source "${SCRIPT_DIR}/lib/deploy/compose.sh"
source "${SCRIPT_DIR}/lib/deploy/summary.sh"
source "${SCRIPT_DIR}/lib/deploy/restart.sh"

###############################################################################
# Main
###############################################################################

print_header "Monitoring-netcup deployment"

#
# Verify environment.
#
check_environment

#
# Verify Docker environment.
#
check_docker_environment

#
# Sync project structure.
#

deploy_sync_stack
#
# Verify project structure.
#
deploy_verify_project

#
# Verify .env.
#
deploy_check_env

#
# Deploy Dockge.
#
deploy_dockge

#
# Validate Docker Compose configuration.
#
deploy_validate_compose

#
# Deploy Monitoring-netcup stack.
#
deploy_compose

deploy_restart_services

#
# Wait until Dockge is ready.
#
deploy_wait_dockge

#
# Print deployment summary.
#
deploy_summary

print_footer "Deployment completed."
