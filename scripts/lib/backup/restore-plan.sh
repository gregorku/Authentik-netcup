#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# File:
#   scripts/lib/backup/restore-plan.sh
#
# Description:
#   Decisions made before a restore writes anything.
#
#   The static tests call these functions. They do not copy files into
#   DATA_DIR and they do not call pg_restore.
#
###############################################################################

###############################################################################
# Confirmation must be the stack name, typed explicitly
#
# Arguments:
#   $1 - Value passed to --confirm
#
###############################################################################

restore_confirmation_matches()
{
    local confirm="$1"

    [[ "${confirm}" == "${STACK_NAME}" ]]
}

###############################################################################
# Compare the manifest tag with the runtime Authentik tag
#
# Arguments:
#   $1 - Tag recorded in the manifest
#   $2 - Tag in the current .env
#   $3 - "yes" to allow a mismatch
#
###############################################################################

restore_versions_match()
{
    local manifest_tag="$1"
    local runtime_tag="$2"
    local allow_mismatch="$3"

    if [[ "${manifest_tag}" == "${runtime_tag}" ]]; then
        return 0
    fi

    [[ "${allow_mismatch}" == "yes" ]]
}
