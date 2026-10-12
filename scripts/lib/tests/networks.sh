#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# Docker network validation.
#
###############################################################################

test_networks()
{
    print_section "Docker networks"

    docker_network_exists "${NETWORK_INTERNAL}"         || fail "Missing Docker network: ${NETWORK_INTERNAL}"

    ok "Docker networks OK."
}
