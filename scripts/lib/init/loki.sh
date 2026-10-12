#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/lib/init/loki.sh
#
# Description:
#   Initialize Loki directory structure.
#
###############################################################################

init_loki()
{
    print_section "Loki"

    ensure_directory "${LOKI_DIR}"

    #
    # The official grafana/loki image runs as the
    # unprivileged "loki" user (10001:10001). Without this,
    # Loki fails to write its data to the bind-mounted
    # data directory.
    #

    ensure_directory_owner \
        "${LOKI_DIR}/data" \
        "10001:10001"

    ok "Loki layout ready."
}
