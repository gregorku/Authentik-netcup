#!/usr/bin/env bash
init_networks() {
    # No network is created here. Compose creates it at explicit deployment.
    # Inspecting existing networks is informational; IPAM is intentionally absent.
    docker network ls --format '{{.Name}}' >&2
}
