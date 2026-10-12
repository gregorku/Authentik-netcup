#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/lib/init/blackbox.sh
#
# Description:
#   Initialize Blackbox Exporter directory structure.
#
###############################################################################

init_blackbox()
{
    print_section "Blackbox Exporter"

    ensure_directory "${BLACKBOX_EXPORTER_DIR}"

    ok "Blackbox Exporter layout ready."
}
