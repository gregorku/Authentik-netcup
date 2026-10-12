#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/lib/init/prometheus.sh
#
# Description:
#   Initialize Prometheus directory structure.
#
###############################################################################

init_prometheus()
{
    print_section "Prometheus"

    ensure_directory "${PROMETHEUS_DIR}"

    #
    # The official prom/prometheus image runs as the
    # unprivileged "nobody" user (65534:65534). Without
    # this, Prometheus panics on startup with
    # "permission denied" writing /prometheus/queries.active.
    #

    ensure_directory_owner \
        "${PROMETHEUS_DIR}/data" \
        "65534:65534"

    ok "Prometheus layout ready."
}
