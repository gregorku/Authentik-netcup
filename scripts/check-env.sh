#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/check-env.sh
#
# Description:
#   Validate Monitoring-netcup environment configuration.
#
###############################################################################

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-/docker-data/stacks/authentik-netcup/.env}"
[[ -r "$ENV_FILE" ]] || { echo "Missing runtime .env: $ENV_FILE" >&2; exit 1; }
set -a; source "$ENV_FILE"; set +a
for name in COMPOSE_PROJECT_NAME DATA_DIR AUTHENTIK_HOST_IP AUTHENTIK_HTTP_PORT AUTHENTIK_VERSION POSTGRES_VERSION REDIS_VERSION AUTHENTIK_SECRET_KEY POSTGRES_PASSWORD POSTGRES_DB POSTGRES_USER; do
  [[ -n "${!name:-}" ]] || { echo "Required variable is empty: $name" >&2; exit 1; }
done
[[ "$COMPOSE_PROJECT_NAME" == authentik-netcup ]] || { echo "COMPOSE_PROJECT_NAME must be authentik-netcup" >&2; exit 1; }
[[ "$AUTHENTIK_HOST_IP" == 10.10.10.100 ]] || { echo "AUTHENTIK_HOST_IP must be 10.10.10.100" >&2; exit 1; }
[[ "$AUTHENTIK_SECRET_KEY" != REPLACE_WITH_* && "$POSTGRES_PASSWORD" != REPLACE_WITH_* ]] || { echo "Replace example secrets" >&2; exit 1; }
[[ ${#POSTGRES_PASSWORD} -le 99 ]] || { echo "POSTGRES_PASSWORD must be at most 99 characters" >&2; exit 1; }
echo "Runtime environment is valid."

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
# Environment library
###############################################################################

source "${SCRIPT_DIR}/lib/env/load.sh"

###############################################################################
# Main
###############################################################################

print_header "Monitoring-netcup Environment Check"

check_environment

print_section "Checking .env"

env_validate

print_footer "Environment configuration OK."
