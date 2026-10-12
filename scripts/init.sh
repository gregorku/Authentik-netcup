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