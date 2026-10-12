#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# Verify that application backends are bound only to the Incus container IP.
# Authentication itself is intentionally handled by Infrastructure-netcup
# Traefik, not by this project.
#
###############################################################################

test_backend_security()
{
    print_section "Backend exposure"

    local monitoring_host_ip
    local ports
    local port

    monitoring_host_ip="$(env_get MONITORING_HOST_IP)"

    ports=(
        "$(env_get GRAFANA_PORT)"
        "$(env_get PROMETHEUS_PORT)"
        "$(env_get ALERTMANAGER_PORT)"
        "$(env_get LOKI_PORT)"
        "$(env_get ALLOY_PORT)"
    )

    for port in "${ports[@]}"; do

        docker ps --format '{{.Ports}}' \
            | grep -Eq "(^|, )${monitoring_host_ip}:${port}->" \
            || fail "Port ${port} is not bound to ${monitoring_host_ip}."

    done

    ok "Application backends are bound to ${monitoring_host_ip}."

    #
    # Blackbox Exporter
    #
    # Blackbox Exporter is an internal monitoring service.
    # Prometheus accesses it through the Docker network using
    # the container name "blackbox-exporter" on port 9115.
    #
    # Port 9115 must therefore NOT be published on the
    # monitoring host.
    #

    if docker ps --format '{{.Names}}' \
        | grep -qx "blackbox-exporter"; then

        docker ps --format '{{.Ports}}' \
            | grep -Eq "(^|, )${monitoring_host_ip}:9115->" \
            && fail "Blackbox Exporter port 9115 must not be exposed on ${monitoring_host_ip}."

        ok "Blackbox Exporter is not exposed on ${monitoring_host_ip}."

    fi

    log_info \
        "Final access control is provided by the Infrastructure-netcup firewall and Traefik BasicAuth."
}
