#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/lib/init/alertmanager.sh
#
# Description:
#   Initialize Alertmanager directory structure.
#
###############################################################################

init_alertmanager()
{
    print_section "Alertmanager"

    ensure_directory "${ALERTMANAGER_DIR}"

    #
    # The official prom/alertmanager image runs as the
    # unprivileged "nobody" user (65534:65534). Without this,
    # Alertmanager fails to write its data to the bind-mounted
    # data directory.
    #

    ensure_directory_owner \
        "${ALERTMANAGER_DIR}/data" \
        "65534:65534"

    ok "Alertmanager layout ready."
}
