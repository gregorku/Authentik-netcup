#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# Prepare persistent service directories.
#
###############################################################################

init_directories()
{
    log_step "Project directories"

    ensure_directory "${DATA_DIR}"

    ensure_directory "${GRAFANA_DIR}"
    ensure_directory "${PROMETHEUS_DIR}"
    ensure_directory "${ALERTMANAGER_DIR}"
    ensure_directory "${LOKI_DIR}"
    ensure_directory "${ALLOY_DIR}"

    log_success "Project directories ready."
}
