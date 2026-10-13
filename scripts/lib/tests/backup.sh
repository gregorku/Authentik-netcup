#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# File:
#   scripts/lib/tests/backup.sh
#
# Description:
#   Backup and restore checks that use a temporary directory.
#
#   They do not call pg_dump, pg_restore, or the production data paths.
#
###############################################################################

test_backup_archive()
{
    print_section "Backup archive"

    local work
    local stage
    local archive
    local extracted

    work="$(mktemp -d)"
    stage="${work}/stage"
    archive="${work}/sample.tar.gz"
    extracted="${work}/extracted"

    mkdir -p "${stage}/postgresql" "${stage}/authentik/data"

    printf 'dump\n' > "${stage}/postgresql/authentik.dump"
    printf 'media\n' > "${stage}/authentik/data/icon.txt"
    printf 'secret\n' > "${stage}/stack.env"

    backup_write_manifest \
        "${stage}" \
        "2026-10-13T00:00:00Z" \
        "ghcr.io/goauthentik/server" \
        "2026.8.3" \
        "docker.io/library/postgres:16-alpine"

    backup_verify_tree "${stage}"

    backup_pack_stage "${stage}" "${archive}"

    backup_verify_archive "${archive}" "${extracted}"

    mkdir -p "${work}/moved"
    cp "${archive}" "${archive}.sha256" "${work}/moved/"
    backup_verify_archive \
        "${work}/moved/$(basename "${archive}")" \
        "${work}/moved-extracted"

    printf 'x\n' >> "${extracted}/stack.env"

    local rejected

    rejected="$(backup_verify_tree "${extracted}" 2>&1)" || true

    [[ "${rejected}" == *"Checksum mismatch"* ]] \
        || fail "A modified backup tree was not rejected: ${rejected}"

    rm -rf "${work}"

    ok "Backup manifest detects a modified file."
}

test_restore_confirmation()
{
    print_section "Restore confirmation"

    restore_confirmation_matches "${STACK_NAME}" \
        || fail "The stack name was rejected as a restore confirmation."

    if restore_confirmation_matches "monitoring-netcup"; then
        fail "A foreign confirmation was accepted."
    fi

    restore_versions_match "2026.8.3" "2026.8.3" "no" \
        || fail "Matching Authentik tags were rejected."

    if restore_versions_match "2026.8.3" "2025.10.0" "no"; then
        fail "A version mismatch was accepted."
    fi

    restore_versions_match "2026.8.3" "2025.10.0" "yes" \
        || fail "An explicit version mismatch was rejected."

    ok "Restore confirmation and version check OK."
}
