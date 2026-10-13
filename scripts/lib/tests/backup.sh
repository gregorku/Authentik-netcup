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

###############################################################################
# Sixty-character value that is not a placeholder
#
# Arguments:
#   $1 - Character to repeat
#
###############################################################################

test_secret_value()
{
    local char="$1"

    printf '%60s' '' | tr ' ' "${char}"
}

###############################################################################
# Stage directory restore is willing to accept
#
# Arguments:
#   $1 - Stage directory
#   $2 - AUTHENTIK_SECRET_KEY
#   $3 - Marker stored in authentik/data/icon.txt
#
###############################################################################

test_fill_backup_stage()
{
    local stage="$1"
    local key="$2"
    local marker="$3"

    mkdir -p \
        "${stage}/postgresql" \
        "${stage}/authentik/data" \
        "${stage}/authentik/templates" \
        "${stage}/authentik/certs"

    printf 'dump\n' > "${stage}/postgresql/authentik.dump"
    printf '%s\n' "${marker}" > "${stage}/authentik/data/icon.txt"
    printf 'template\n' > "${stage}/authentik/templates/custom.html"
    printf 'cert\n' > "${stage}/authentik/certs/cert.pem"

    printf 'AUTHENTIK_SECRET_KEY=%s\nAUTHENTIK_EMAIL__HOST=smtp.archived\nBACKUP_EXTERNAL_DIR=/mnt/archived\n' \
        "${key}" > "${stage}/stack.env"

    chmod 600 "${stage}/stack.env"

    backup_write_manifest \
        "${stage}" \
        "2026-10-13T00:00:00Z" \
        "ghcr.io/goauthentik/server" \
        "2026.8.3" \
        "docker.io/library/postgres:16-alpine"
}

###############################################################################
# Refuse archives that must not reach live data
###############################################################################

test_restore_rejects_incomplete()
{
    print_section "Restore preflight"

    local work
    local stage
    local live
    local env_file
    local rejected
    local key

    work="$(mktemp -d)"
    key="$(test_secret_value a)"
    stage="${work}/stage"
    live="${work}/live"
    env_file="${work}/runtime.env"

    mkdir -p "${live}/data" "${live}/templates" "${live}/certs"
    printf 'sentinel\n' > "${live}/data/sentinel.txt"
    printf 'AUTHENTIK_SECRET_KEY=%s\nAUTHENTIK_EMAIL__HOST=smtp.current\n' \
        "${key}" > "${env_file}"

    test_fill_backup_stage "${stage}" "${key}" "archive"
    rm -f "${stage}/postgresql/authentik.dump"

    rejected="$(restore_validate_stage "${stage}" 2>&1)" || true

    [[ "${rejected}" == *"PostgreSQL dump is missing or empty."* ]] \
        || fail "A backup without a database dump was accepted: ${rejected}"

    test_fill_backup_stage "${stage}" "${key}" "archive"
    rm -rf "${stage}/authentik/templates"

    rejected="$(restore_validate_stage "${stage}" 2>&1)" || true

    [[ "${rejected}" == *"Archive is missing authentik/templates."* ]] \
        || fail "A backup without persistent directories was accepted: ${rejected}"

    test_fill_backup_stage "${stage}" "${key}" "archive"
    printf 'AUTHENTIK_EMAIL__HOST=smtp.archived\n' > "${stage}/stack.env"

    rejected="$(restore_validate_stage "${stage}" 2>&1)" || true

    [[ "${rejected}" == *"no AUTHENTIK_SECRET_KEY"* ]] \
        || fail "A backup without AUTHENTIK_SECRET_KEY was accepted: ${rejected}"

    printf 'AUTHENTIK_SECRET_KEY=set_authentik_secret_key\n' > "${stage}/stack.env"

    rejected="$(restore_validate_stage "${stage}" 2>&1)" || true

    [[ "${rejected}" == *"placeholder, or shorter than 50 characters."* ]] \
        || fail "A placeholder AUTHENTIK_SECRET_KEY was accepted: ${rejected}"

    printf 'AUTHENTIK_SECRET_KEY=short-key\n' > "${stage}/stack.env"

    rejected="$(restore_validate_stage "${stage}" 2>&1)" || true

    [[ "${rejected}" == *"placeholder, or shorter than 50 characters."* ]] \
        || fail "A short AUTHENTIK_SECRET_KEY was accepted: ${rejected}"

    test_fill_backup_stage "${stage}" "${key}" "archive"
    printf 'changed\n' >> "${stage}/authentik/data/icon.txt"

    rejected="$(restore_validate_stage "${stage}" 2>&1)" || true

    [[ "${rejected}" == *"Checksum mismatch"* ]] \
        || fail "A modified backup file was accepted: ${rejected}"

    test_fill_backup_stage "${stage}" "${key}" "archive"
    printf 'project=monitoring-netcup\n' > "${stage}/manifest.txt"

    rejected="$(restore_validate_stage "${stage}" 2>&1)" || true

    [[ "${rejected}" == *"Manifest project is"* ]] \
        || fail "An invalid manifest was accepted: ${rejected}"

    TEST_SNAPSHOT_FLAG="${work}/snapshot-called"
    rm -f "${TEST_SNAPSHOT_FLAG}"

    restore_snapshot_database()
    {
        printf 'called\n' > "${TEST_SNAPSHOT_FLAG}"
        return 0
    }

    rm -f "${stage}/postgresql/authentik.dump"

    rejected="$(restore_perform "${stage}" "${live}" "${env_file}" "${work}/rollback" 2>&1)" || true

    [[ "${rejected}" == *"PostgreSQL dump is missing or empty."* ]] \
        || fail "Preflight did not reject the incomplete archive: ${rejected}"

    [[ ! -e "${TEST_SNAPSHOT_FLAG}" ]] \
        || fail "Validation failure still prepared a database snapshot."

    [[ "$(cat "${live}/data/sentinel.txt")" == "sentinel" ]] \
        || fail "Validation failure changed live files."

    rm -rf "${work}"

    ok "Incomplete archives are refused before live data changes."
}

###############################################################################
# Database failure puts files and the key back
###############################################################################

test_restore_rolls_back()
{
    print_section "Restore rollback"

    local work
    local stage
    local live
    local env_file
    local rollback
    local old_key
    local new_key
    local live_key

    work="$(mktemp -d)"
    old_key="$(test_secret_value a)"
    new_key="$(test_secret_value b)"
    stage="${work}/stage"
    live="${work}/live"
    env_file="${work}/runtime.env"
    rollback="${work}/rollback"

    mkdir -p "${live}/data" "${live}/templates" "${live}/certs" "${rollback}"
    printf 'original\n' > "${live}/data/icon.txt"
    printf 'original-template\n' > "${live}/templates/custom.html"
    printf 'original-cert\n' > "${live}/certs/cert.pem"

    printf 'AUTHENTIK_SECRET_KEY=%s\nAUTHENTIK_EMAIL__HOST=smtp.current\nBACKUP_EXTERNAL_DIR=/mnt/current\n' \
        "${old_key}" > "${env_file}"

    test_fill_backup_stage "${stage}" "${new_key}" "from-archive"

    TEST_LOAD_MODE="fail-once"

    restore_snapshot_database()
    {
        printf 'snapshot\n' > "$1"
    }

    restore_load_database()
    {
        if [[ "${TEST_LOAD_MODE}" == "fail-once" ]]; then
            TEST_LOAD_MODE="ok"
            return 1
        fi

        if [[ "${TEST_LOAD_MODE}" == "fail" ]]; then
            return 1
        fi

        return 0
    }

    restore_database_is_ready()
    {
        return 0
    }

    if restore_perform "${stage}" "${live}" "${env_file}" "${rollback}"; then
        fail "A failed database restore was reported as success."
    fi

    [[ "${RESTORE_ERROR}" == "rolled-back" ]] \
        || fail "Database failure did not roll back (${RESTORE_ERROR})."

    restore_should_keep_rollback \
        || fail "A rolled-back restore would discard its snapshot."

    [[ "$(cat "${live}/data/icon.txt")" == "original" ]] \
        || fail "Rollback left archive files in place of the original data."

    live_key="$(restore_read_secret_key "${env_file}")"

    [[ "${live_key}" == "${old_key}" ]] \
        || fail "Rollback did not restore the previous secret key."

    grep -qx 'AUTHENTIK_EMAIL__HOST=smtp.current' "${env_file}" \
        || fail "Rollback changed a non-key environment line."

    [[ -s "${rollback}/postgresql/authentik.dump" ]] \
        || fail "Rollback snapshot dump is missing."

    TEST_LOAD_MODE="fail"

    if restore_perform "${stage}" "${live}" "${env_file}" "${rollback}"; then
        fail "A restore whose rollback also failed was reported as success."
    fi

    [[ "${RESTORE_ERROR}" == "rollback-failed" ]] \
        || fail "A failed rollback was not reported (${RESTORE_ERROR})."

    [[ "$(cat "${live}/data/icon.txt")" == "original" ]] \
        || fail "A failed database rollback left archive files in place."

    live_key="$(restore_read_secret_key "${env_file}")"

    [[ "${live_key}" == "${old_key}" ]] \
        || fail "A failed database rollback left the archive secret key installed."

    unset live_key old_key new_key

    rm -rf "${work}"

    ok "Database restore failure does not report success."
}

###############################################################################
# Secret key is replaced without rewriting the rest of .env
###############################################################################

test_restore_installs_secret_key()
{
    print_section "Restore secret key"

    local work
    local stage
    local live
    local env_file
    local rollback
    local old_key
    local new_key
    local live_key
    local mode
    local backup_file

    work="$(mktemp -d)"
    old_key="$(test_secret_value a)"
    new_key="$(test_secret_value b)"
    stage="${work}/stage"
    live="${work}/live"
    env_file="${work}/runtime.env"
    rollback="${work}/rollback"

    mkdir -p "${live}/data" "${live}/templates" "${live}/certs" "${rollback}"
    printf 'original\n' > "${live}/data/icon.txt"
    printf 'original-template\n' > "${live}/templates/custom.html"
    printf 'original-cert\n' > "${live}/certs/cert.pem"

    printf 'AUTHENTIK_SECRET_KEY=%s\nAUTHENTIK_EMAIL__HOST=smtp.current\nBACKUP_EXTERNAL_DIR=/mnt/current\n' \
        "${old_key}" > "${env_file}"

    chmod 640 "${env_file}"

    test_fill_backup_stage "${stage}" "${new_key}" "from-archive"

    restore_snapshot_database()
    {
        printf 'snapshot\n' > "$1"
    }

    restore_load_database()
    {
        return 0
    }

    restore_database_is_ready()
    {
        return 0
    }

    if ! restore_perform "${stage}" "${live}" "${env_file}" "${rollback}"; then
        fail "Secret key restore failed (${RESTORE_ERROR})."
    fi

    [[ -z "${RESTORE_ERROR}" ]] \
        || fail "Successful restore left an error state (${RESTORE_ERROR})."

    live_key="$(restore_read_secret_key "${env_file}")"

    [[ "${live_key}" == "${new_key}" ]] \
        || fail "Runtime secret key does not match the archive."

    grep -qx 'AUTHENTIK_EMAIL__HOST=smtp.current' "${env_file}" \
        || fail "Secret key restore rewrote AUTHENTIK_EMAIL__HOST."

    grep -qx 'BACKUP_EXTERNAL_DIR=/mnt/current' "${env_file}" \
        || fail "Secret key restore rewrote BACKUP_EXTERNAL_DIR."

    [[ "$(grep -c '^AUTHENTIK_SECRET_KEY=' "${env_file}")" -eq 1 ]] \
        || fail "Secret key restore left more than one key line."

    [[ "$(cat "${live}/data/icon.txt")" == "from-archive" ]] \
        || fail "Restored data file does not match the archive."

    mode="$(stat -c '%a' "${env_file}")"

    [[ "${mode}" == "640" ]] \
        || fail "Secret key restore changed .env mode from 640 to ${mode}."

    backup_file="$(find "${work}" -maxdepth 1 -name 'runtime.env.bak-*' -type f -print -quit)"

    [[ -n "${backup_file}" && -f "${backup_file}" ]] \
        || fail "Secret key restore did not keep a backup of .env."

    [[ "$(stat -c '%a' "${backup_file}")" == "600" ]] \
        || fail "The .env backup is not mode 600."

    unset live_key old_key new_key

    rm -rf "${work}"

    ok "Secret key restored without rewriting other .env lines."
}

###############################################################################
# External copy is checked where it was copied
###############################################################################

test_backup_external_copy()
{
    print_section "External backup copy"

    local work
    local stage
    local archive
    local dest
    local rejected
    local key

    work="$(mktemp -d)"
    key="$(test_secret_value c)"
    stage="${work}/stage"
    archive="${work}/sample.tar.gz"
    dest="${work}/external"

    test_fill_backup_stage "${stage}" "${key}" "media"
    backup_pack_stage "${stage}" "${archive}"

    mkdir -p "${dest}"

    backup_copy_and_verify "${archive}" "${dest}"

    printf 'x\n' >> "${dest}/$(basename "${archive}")"

    rejected="$(backup_require_sidecar "${dest}/$(basename "${archive}")" copy 2>&1)" || true

    [[ "${rejected}" == *"not a verified backup"* ]] \
        || fail "A damaged external copy was accepted: ${rejected}"

    backup_verify_sidecar "${archive}" \
        || fail "The local archive failed after the external copy was damaged."

    unset key

    rm -rf "${work}"

    ok "External copy is verified at the destination."
}

###############################################################################
# Backup stops only the Authentik containers that are running
###############################################################################

test_backup_quiesce()
{
    print_section "Backup quiesce"

    local work
    local events

    work="$(mktemp -d)"
    events="${work}/events"
    : > "${events}"

    (
        docker_container_running()
        {
            [[ "$1" == "${AUTHENTIK_SERVER_CONTAINER}" ]]
        }

        backup_stop_container()
        {
            printf 'stop %s\n' "$1" >> "${events}"
        }

        backup_start_container()
        {
            printf 'start %s\n' "$1" >> "${events}"
        }

        backup_quiesce_writers
        backup_resume_writers
    ) || fail "Backup quiesce returned an error."

    grep -qx "stop ${AUTHENTIK_SERVER_CONTAINER}" "${events}" \
        || fail "A running Authentik server was not stopped for the backup."

    grep -qx "start ${AUTHENTIK_SERVER_CONTAINER}" "${events}" \
        || fail "The Authentik server stopped for the backup was not started again."

    if grep -q "${AUTHENTIK_WORKER_CONTAINER}" "${events}"; then
        fail "An already stopped worker was changed by the backup."
    fi

    rm -rf "${work}"

    ok "Backup stops and starts only the containers it found running."
}
