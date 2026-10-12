#!/usr/bin/env bash
set -Eeuo pipefail
stack=/docker-data/stacks/authentik-netcup
[[ -r "$stack/.env" ]] || { echo 'Runtime .env is unavailable.' >&2; exit 1; }
docker compose --env-file "$stack/.env" -f "$stack/compose.yml" ps
echo 'Confirm health, DNS, TLS, firewall and Traefik separately; this script does not claim those checks passed.'
