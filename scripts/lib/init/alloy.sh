#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/lib/init/alloy.sh
#
# Description:
#   Initialize Alloy directory structure.
#
###############################################################################

init_alloy()
{
    print_section "Alloy"

    ensure_directory "${ALLOY_DIR}"

    #
    # The official grafana/alloy image runs as the
    # unprivileged "alloy" user (10001:10001). Without this,
    # Alloy fails to write its data to the bind-mounted
    # data directory.
    #

    ensure_directory_owner \
        "${ALLOY_DIR}/data" \
        "10001:10001"

    ok "Alloy layout ready."
}
