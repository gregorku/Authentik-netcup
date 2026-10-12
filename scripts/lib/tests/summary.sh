#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/lib/tests/summary.sh
#
# Description:
#   Print Monitoring-netcup test summary.
#
###############################################################################

###############################################################################
# Test summary
###############################################################################

test_summary()
{
    print_section "Finished"

    ok "Monitoring-netcup tests completed."

    echo

    info "Review the output above for warnings or failures."

    echo

    ok "Test summary completed."
}