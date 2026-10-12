#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/config.sh
#
# Description:
#   Common configuration shared by all Monitoring-netcup scripts.
#
###############################################################################

set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# Project
###############################################################################

readonly PROJECT_NAME="Monitoring-netcup"

#
# Docker Compose stack name
#
readonly STACK_NAME="monitoring-netcup"

###############################################################################
# Repository
###############################################################################

readonly GIT_DIR="/incus-dir/git/${PROJECT_NAME}"

###############################################################################
# Base directories
###############################################################################

readonly BASE_DIR="/docker-data"

readonly DATA_DIR="${BASE_DIR}/monitoring-netcup"

###############################################################################
# Dockge
###############################################################################

readonly DOCKGE_DIR="${BASE_DIR}/dockge"
readonly DOCKGE_DATA_DIR="${DOCKGE_DIR}/data"

readonly DOCKGE_CONTAINER="dockge"
readonly DOCKGE_IMAGE="louislam/dockge:latest"
readonly DOCKGE_PORT="5001"

###############################################################################
# Docker Compose stacks
###############################################################################

readonly STACKS_DIR="${BASE_DIR}/stacks"
readonly STACK_DIR="${STACKS_DIR}/${STACK_NAME}"

###############################################################################
# Stack files
###############################################################################

readonly COMPOSE_FILE="${STACK_DIR}/compose.yml"
readonly ENV_FILE="${STACK_DIR}/.env"
readonly ENV_EXAMPLE_FILE="${STACK_DIR}/.env.example"

###############################################################################
# Files copied during initialization
###############################################################################

readonly DEPLOY_ITEMS=(
    compose.yml
    compose
    configs
    .env.example
)

###############################################################################
# Docker networks
###############################################################################

readonly NETWORK_INTERNAL="monitoring-netcup"
readonly NETWORK_INTERNAL_SUBNET="10.40.0.0/16"
readonly NETWORK_INTERNAL_GATEWAY="10.40.0.1"

###############################################################################
# Colors
###############################################################################

readonly COLOR_RED="\033[0;31m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_RESET="\033[0m"

###############################################################################
# Grafana
###############################################################################

readonly GRAFANA_SERVICE="grafana"
readonly GRAFANA_DIR="${DATA_DIR}/grafana"

###############################################################################
# Prometheus
###############################################################################

readonly PROMETHEUS_SERVICE="prometheus"
readonly PROMETHEUS_DIR="${DATA_DIR}/prometheus"

###############################################################################
# SNMP exporter
###############################################################################

readonly SNMP_EXPORTER_SERVICE="snmp-exporter"
readonly SNMP_EXPORTER_DIR="${DATA_DIR}/snmp-exporter"

###############################################################################
# Blackbox exporter
###############################################################################

readonly BLACKBOX_EXPORTER_SERVICE="blackbox-exporter"
readonly BLACKBOX_EXPORTER_DIR="${DATA_DIR}/blackbox-exporter"

###############################################################################
# Alertmanager
###############################################################################

readonly ALERTMANAGER_DIR="${DATA_DIR}/alertmanager"

###############################################################################
# Loki
###############################################################################

readonly LOKI_DIR="${DATA_DIR}/loki"

###############################################################################
# Alloy
###############################################################################

readonly ALLOY_DIR="${DATA_DIR}/alloy"