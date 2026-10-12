#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/lib/init/grafana.sh
#
# Description:
#   Initialize Grafana directory structure.
#
###############################################################################

init_grafana()
{
    print_section "Grafana"

    ensure_directory "${GRAFANA_DIR}"

    #
    # The official grafana/grafana image runs as the
    # unprivileged "grafana" user (472:472). Without this,
    # Grafana fails to write its SQLite database / plugins
    # to the bind-mounted data directory.
    #

    ensure_directory_owner \
        "${GRAFANA_DIR}/data" \
        "472:472"

    ok "Grafana layout ready."
}
