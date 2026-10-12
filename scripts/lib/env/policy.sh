#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# Environment variable policies.
#
###############################################################################

declare -gA ENV_POLICY

###############################################################################
# General
###############################################################################

ENV_POLICY[TZ]="user"

###############################################################################
# Docker Compose
###############################################################################

ENV_POLICY[COMPOSE_PROJECT_NAME]="framework"

###############################################################################
# Monitoring host / backend ports
###############################################################################

ENV_POLICY[MONITORING_HOST_IP]="user"

ENV_POLICY[GRAFANA_PORT]="framework"
ENV_POLICY[PROMETHEUS_PORT]="framework"
ENV_POLICY[ALERTMANAGER_PORT]="framework"
ENV_POLICY[LOKI_PORT]="framework"
ENV_POLICY[ALLOY_PORT]="framework"

###############################################################################
# Grafana
###############################################################################

ENV_POLICY[GRAFANA_VERSION]="framework"
ENV_POLICY[GRAFANA_ADMIN_USER]="user"
ENV_POLICY[GRAFANA_ADMIN_PASSWORD]="user"
ENV_POLICY[GRAFANA_DOMAIN]="user"
ENV_POLICY[IP_GRAFANA]="user"

###############################################################################
# Prometheus
###############################################################################

ENV_POLICY[PROMETHEUS_VERSION]="framework"
ENV_POLICY[PROMETHEUS_RETENTION]="user"
ENV_POLICY[IP_PROMETHEUS]="user"
ENV_POLICY[PROMETHEUS_PUBLIC_URL]="user"

###############################################################################
# SNMP exporter
###############################################################################

ENV_POLICY[SNMP_EXPORTER_VERSION]="framework"
ENV_POLICY[IP_SNMP_EXPORTER]="user"

###############################################################################
# Alertmanager
###############################################################################

ENV_POLICY[ALERTMANAGER_VERSION]="framework"
ENV_POLICY[ALERTMANAGER_PUBLIC_URL]="user"
ENV_POLICY[IP_ALERTMANAGER]="user"

###############################################################################
# Loki
###############################################################################

ENV_POLICY[LOKI_VERSION]="framework"
ENV_POLICY[IP_LOKI]="user"

###############################################################################
# Alloy
###############################################################################

ENV_POLICY[ALLOY_VERSION]="framework"
ENV_POLICY[IP_ALLOY]="user"

###############################################################################
# Persistent data
###############################################################################

ENV_POLICY[DATA_DIR]="user"

###############################################################################
# Logging
###############################################################################

ENV_POLICY[LOG_MAX_SIZE]="framework"
ENV_POLICY[LOG_MAX_FILES]="framework"

###############################################################################
# Return variable policy
###############################################################################

env_variable_policy()
{
    local variable="$1"

    printf '%s\n' "${ENV_POLICY[$variable]:-user}"
}

###############################################################################
# Variable exists in policy
###############################################################################

env_is_known_variable()
{
    local variable="$1"

    [[ -v ENV_POLICY["$variable"] ]]
}
