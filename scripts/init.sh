#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/init.sh
#
# Description:
#   Initialize Monitoring-netcup project.
#
# Responsibilities:
#   - Verify environment
#   - Prepare project directories
#   - Prepare project stack
#   - Create Docker networks
#   - Prepare service layouts
#
###############################################################################

set -Eeuo pipefail

# Authentik-netcup implementation (the legacy template below is unreachable).
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; stack=/docker-data/stacks/authentik-netcup; data=/docker-data/authentik-netcup
command -v docker >/dev/null || { echo 'Docker is required' >&2; exit 1; }
docker ps --format '{{.Names}}' | grep -qx dockge || { echo 'Dockge is not running; it is not installed by this project.' >&2; exit 1; }
mkdir -p "$stack" "$data"/{postgresql,redis,media,custom-templates,certs,blueprints}
"$repo/scripts/deploy.sh" --sync-only
docker network inspect authentik-netcup_internal >/dev/null 2>&1 && echo 'Existing Authentik network found (review for collisions).' || true
echo 'Initialization complete. Set real secrets in runtime .env before deploy.'
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
source "${SCRIPT_DIR}/lib/git.sh"

###############################################################################
# Checks
###############################################################################

source "${SCRIPT_DIR}/lib/checks/load.sh"

###############################################################################
# Initialization modules
###############################################################################

source "${SCRIPT_DIR}/lib/init/directories.sh"
source "${SCRIPT_DIR}/lib/init/stack.sh"
source "${SCRIPT_DIR}/lib/init/grafana.sh"
source "${SCRIPT_DIR}/lib/init/prometheus.sh"
source "${SCRIPT_DIR}/lib/init/alertmanager.sh"
source "${SCRIPT_DIR}/lib/init/loki.sh"
source "${SCRIPT_DIR}/lib/init/alloy.sh"
source "${SCRIPT_DIR}/lib/init/blackbox.sh"
source "${SCRIPT_DIR}/lib/init/summary.sh"

###############################################################################
# Main
###############################################################################

print_header "Monitoring-netcup initialization"

#
# Verify environment.
#
check_environment

#
# Prepare project directories.
#
init_directories

#
# Prepare project stack.
#
init_stack

#
# Create Docker networks.
#
init_networks

#
# Prepare Grafana layout.
#
init_grafana

#
# Prepare Prometheus layout.
#
init_prometheus

#
# Prepare Blackbox Exporter layout.
#
init_blackbox

#
# Prepare Alertmanager layout.
#
init_alertmanager

#
# Prepare Loki layout.
#
init_loki

#
# Prepare Alloy layout.
#
init_alloy

#
# Print summary.
#
init_summary
