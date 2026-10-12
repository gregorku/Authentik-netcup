#!/usr/bin/env bash
env_validate() {
    declare -A ENV
    env_read_current ENV
    local variable
    for variable in "${!ENV_POLICY[@]}"; do
        [[ -v ENV[$variable] ]] || fail "Missing variable: ${variable}"
    done
}
