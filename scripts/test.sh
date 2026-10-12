#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/test.sh
#
# Description:
#   Run Monitoring-netcup framework tests.
#
###############################################################################

set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; stack=/docker-data/stacks/authentik-netcup
find "$repo/scripts" -type f -name '*.sh' -exec bash -n {} +
grep -q 'AUTHENTIK_HOST_IP=10.10.10.100' "$repo/.env.example"
! grep -Eq '^\s*(ports:|.*5432:|.*6379:)' "$repo/compose/10-authentik.yml"
grep -q 'for item in compose.yml compose configs .env.example' "$repo/scripts/deploy.sh"
[[ -r "$stack/.env" ]] && "$repo/scripts/check-env.sh" "$stack/.env" || echo 'SKIP runtime tests: runtime .env is unavailable.'
[[ -r "$stack/.env" ]] && docker compose --env-file "$stack/.env" -f "$repo/compose.yml" config -q || true
echo 'Static checks passed. Network/firewall and running-service tests require the target container and are not claimed here.'
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
source "${SCRIPT_DIR}/lib/filesystem.sh"
source "${SCRIPT_DIR}/lib/docker.sh"

###############################################################################
# Checks library
###############################################################################

source "${SCRIPT_DIR}/lib/checks/load.sh"

###############################################################################
# Environment library
###############################################################################

source "${SCRIPT_DIR}/lib/env/load.sh"

###############################################################################
# Test modules
###############################################################################

source "${SCRIPT_DIR}/lib/tests/project.sh"
source "${SCRIPT_DIR}/lib/tests/stack.sh"
source "${SCRIPT_DIR}/lib/tests/environment.sh"
source "${SCRIPT_DIR}/lib/tests/compose.sh"
source "${SCRIPT_DIR}/lib/tests/docker.sh"
source "${SCRIPT_DIR}/lib/tests/dockge.sh"
source "${SCRIPT_DIR}/lib/tests/networks.sh"
source "${SCRIPT_DIR}/lib/tests/backend-security.sh"

###############################################################################
# Services
###############################################################################

source "${SCRIPT_DIR}/lib/tests/summary.sh"

###############################################################################
# Main
###############################################################################

print_header "Monitoring-netcup test"

check_environment
check_docker_environment

test_project
test_stack
test_environment
test_compose
test_docker
test_dockge
test_networks
test_backend_security

###############################################################################
# Services
###############################################################################

#
# Post deployment
#

test_summary
