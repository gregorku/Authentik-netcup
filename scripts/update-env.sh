#!/usr/bin/env bash
set -Eeuo pipefail
echo 'Refusing to overwrite runtime .env. Copy .env.example once, then edit /docker-data/stacks/authentik-netcup/.env manually.' >&2
exit 1
