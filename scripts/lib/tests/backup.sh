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

    [[ "${RESTORE_KEEP_ROLLBACK}" == "yes" ]] \
        || fail "Database failure cleared the rollback keep flag."

    [[ "${RESTORE_MUTATION_STARTED}" == "yes" ]] \
        || fail "Database failure lost the mutation marker."

    [[ -d "${rollback}" ]] \
        || fail "Database failure removed the rollback snapshot."

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

###############################################################################
# age encryption of a real temporary archive
#
# age-keygen, age -r and age -d run for real. Docker and PostgreSQL
# do not. The private identity is not printed.
#
###############################################################################

test_backup_encryption()
{
    print_section "Backup encryption"

    local work
    local empty_bin
    local rejected
    local identity
    local recipient
    local plain
    local encrypted
    local restored
    local mode

    work="$(mktemp -d)"
    empty_bin="${work}/empty-bin"
    mkdir -m 700 "${empty_bin}"

    rejected="$(backup_require_encryption "" 2>&1)" || true

    [[ "${rejected}" == *"BACKUP_AGE_RECIPIENT is empty"* ]] \
        || fail "An empty age recipient was accepted: ${rejected}"

    [[ "${rejected}" == *"not a safe external backup"* ]] \
        || fail "An empty age recipient was described as a safe external backup: ${rejected}"

    rejected="$(backup_require_encryption "AGE-SECRET-KEY-1not-a-real-identity" 2>&1)" || true

    [[ "${rejected}" == *"not a public age recipient"* ]] \
        || fail "A private age identity was accepted as a recipient: ${rejected}"

    [[ "${rejected}" != *"AGE-SECRET-KEY"* ]] \
        || fail "A rejected identity was written to the error text."

    (
        PATH="${empty_bin}"
        hash -r
        backup_require_encryption "age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
    ) >"${work}/missing-age.out" 2>"${work}/missing-age.err" || true

    rejected="$(cat "${work}/missing-age.err")"

    [[ "${rejected}" == *"age is not installed"* ]] \
        || fail "A missing age command was accepted: ${rejected}"

    [[ "${rejected}" == *"not a safe external backup"* ]] \
        || fail "A missing age command was described as a safe external backup: ${rejected}"

    identity="${work}/identity"
    age-keygen -o "${identity}" >"${work}/age-keygen.out" 2>"${work}/age-keygen.err"
    chmod 600 "${identity}"

    recipient="$(
        awk -F': ' '/public key:/{ print $2; exit }' "${identity}"
    )"

    backup_recipient_is_public "${recipient}" \
        || fail "age-keygen did not produce a public recipient."

    plain="${work}/plain.tar.gz"
    encrypted="${work}/sample.tar.gz.age"

    (
        umask 022
        backup_create_private_file "${work}/umask-file"
        backup_create_private_dir "${work}/umask-dir"
    )

    [[ "$(stat -c '%a' "${work}/umask-file")" == "600" ]] \
        || fail "A private file was created with mode $(stat -c '%a' "${work}/umask-file") under umask 022."

    [[ "$(stat -c '%a' "${work}/umask-dir")" == "700" ]] \
        || fail "A private directory was created with mode $(stat -c '%a' "${work}/umask-dir") under umask 022."

    printf 'plaintext-marker\n' > "${work}/payload"
    tar -C "${work}" -czf "${plain}" payload

    (
        umask 022
        backup_encrypt_file "${plain}" "${encrypted}" "${recipient}"
    ) \
        || fail "age did not encrypt the archive."

    mode="$(stat -c '%a' "${encrypted}")"

    [[ "${mode}" == "600" ]] \
        || fail "Encrypted archive mode is ${mode}, expected 600."

    backup_write_checksum "${encrypted}"
    backup_require_sidecar "${encrypted}" "archive"

    printf 'x' >> "${encrypted}"

    rejected="$(backup_require_sidecar "${encrypted}" archive 2>&1)" || true

    [[ "${rejected}" == *"does not match"* ]] \
        || fail "A damaged encrypted archive was accepted: ${rejected}"

    backup_write_checksum "${encrypted}"

    restored="${work}/restored"
    backup_create_private_file "${restored}"

    if backup_decrypt_file "${encrypted}" "${restored}" "${identity}"; then
        fail "A damaged encrypted archive was decrypted."
    fi

    [[ ! -e "${restored}" ]] \
        || fail "A failed decrypt left a plaintext file."

    rm -f "${encrypted}" "${encrypted}.sha256"
    backup_encrypt_file "${plain}" "${encrypted}" "${recipient}" \
        || fail "age did not encrypt the archive on the second attempt."

    backup_write_checksum "${encrypted}"
    backup_decrypt_file "${encrypted}" "${restored}" "${identity}" \
        || fail "age did not decrypt the archive with the identity file."

    mkdir -m 700 "${work}/out"
    tar -C "${work}/out" -xzf "${restored}"

    [[ "$(cat "${work}/out/payload")" == "plaintext-marker" ]] \
        || fail "Decrypted archive does not contain the plaintext payload."

    backup_destroy_file "${plain}" \
        || fail "Plaintext archive could not be removed."

    [[ ! -e "${plain}" ]] \
        || fail "Plaintext archive remained after shred."

    rm -rf "${work}"

    ok "age encryption, checksum and decrypt were checked with a real age binary."
}

###############################################################################
# Destination device and directory mode
#
# Both directories are on this workstation's filesystem. No second
# disk is mounted. The other-filesystem branch is not executed here.
#
###############################################################################

test_backup_destination()
{
    print_section "Backup destination"

    local work
    local local_dir
    local same
    local loose
    local kind
    local rejected

    work="$(mktemp -d)"
    local_dir="${work}/local"
    same="${work}/same"
    loose="${work}/loose"

    mkdir -m 700 "${local_dir}" "${same}"
    mkdir -m 755 "${loose}"

    kind="$(backup_classify_destination "${same}" "${local_dir}")"

    [[ "${kind}" == "same-filesystem" ]] \
        || fail "Two directories on this filesystem were classed as ${kind}."

    rejected="$(backup_publish_encrypted "${work}/missing" "${same}" "${local_dir}" 2>&1)" || true

    [[ "${rejected}" == *"same filesystem"* ]] \
        || fail "A same-filesystem destination was copied: ${rejected}"

    [[ "${rejected}" == *"not an external backup"* ]] \
        || fail "A same-filesystem destination was called an external backup: ${rejected}"

    [[ ! -e "${same}/missing" ]] \
        || fail "A refused destination received a file."

    rejected="$(backup_classify_destination "${loose}" "${local_dir}" 2>&1)" || true

    [[ "${rejected}" == *"mode 700"* ]] \
        || fail "A mode 755 destination was accepted: ${rejected}"

    if backup_path_is_forbidden "${STACK_DIR}/age.key"; then
        true
    else
        fail "An identity under the stack directory was allowed."
    fi

    if backup_path_is_forbidden "${work}/identity"; then
        fail "An identity in a temporary directory was forbidden."
    fi

    printf 'not-a-key\n' > "${work}/identity"
    chmod 644 "${work}/identity"

    rejected="$(backup_require_identity "${work}/identity" 2>&1)" || true

    [[ "${rejected}" == *"mode 600 or 400"* ]] \
        || fail "A mode 644 identity was accepted: ${rejected}"

    chmod 600 "${work}/identity"

    backup_require_identity "${work}/identity"

    rm -rf "${work}"

    ok "Same-filesystem and loose destinations are refused."
}

###############################################################################
# Cleanup failure must not look like success
#
# backup_destroy_tree is replaced in a subshell. shred is not asked
# to fail on a real file; the replacement returns 1 immediately.
#
###############################################################################

test_backup_cleanup_failure()
{
    print_section "Backup cleanup failure"

    local work
    local rejected
    local status

    work="$(mktemp -d)"
    mkdir -m 700 "${work}/plain"
    printf 'secret\n' > "${work}/plain/payload"

    status=0

    rejected="$(
        backup_destroy_tree()
        {
            return 1
        }

        backup_discard_plaintext "${work}/plain"
    )" || status=$?

    [[ "${status}" -ne 0 ]] \
        || fail "A failed plaintext cleanup was treated as success."

    [[ "${rejected}" == *"not a completed backup"* ]] \
        || fail "Cleanup failure was reported as a completed backup: ${rejected}"

    [[ -f "${work}/plain/payload" ]] \
        || fail "The simulated cleanup failure removed the plaintext file."

    rm -rf "${work}"

    ok "A failed plaintext cleanup is not a completed backup."
}

###############################################################################
# SIGTERM during the destructive phase keeps the snapshot
#
# A subshell installs the same EXIT handler as restore.sh and then
# receives a real SIGTERM. pg_restore is a stub that returns 0. No
# database is contacted.
#
###############################################################################

test_restore_signal()
{
    print_section "Restore signal"

    local work
    local live
    local rollback
    local env_file
    local status

    work="$(mktemp -d)"
    live="${work}/live"
    rollback="${work}/rollback"
    env_file="${work}/runtime.env"

    mkdir -m 700 -p "${live}/data" "${live}/templates" "${live}/certs"
    mkdir -m 700 -p "${rollback}/authentik/data" "${rollback}/authentik/templates" "${rollback}/authentik/certs" "${rollback}/postgresql"

    printf 'original\n' > "${live}/data/icon.txt"
    printf 'original\n' > "${rollback}/authentik/data/icon.txt"
    printf 'template\n' > "${live}/templates/custom.html"
    printf 'template\n' > "${rollback}/authentik/templates/custom.html"
    printf 'cert\n' > "${live}/certs/cert.pem"
    printf 'cert\n' > "${rollback}/authentik/certs/cert.pem"
    printf 'AUTHENTIK_SECRET_KEY=%s\n' "$(test_secret_value a)" > "${env_file}"
    install -m 600 "${env_file}" "${rollback}/runtime.env"
    printf '600\n' > "${rollback}/env.mode"
    printf 'snapshot\n' > "${rollback}/postgresql/authentik.dump"

    status=0

    (
        stage=""
        secret_tmp=""
        RESTORE_VERIFIED=no
        RESTORE_ROLLBACK_DONE=no
        RESTORE_ROLLBACK_ATTEMPTED=no
        RESTORE_KEEP_ROLLBACK=yes
        RESTORE_MUTATION_STARTED=yes
        RESTORE_LIVE_ROOT="${live}"
        RESTORE_ENV_FILE="${env_file}"
        RESTORE_ROLLBACK_DIR="${rollback}"

        restore_load_database()
        {
            return 0
        }

        printf 'destroyed\n' > "${live}/data/icon.txt"

        trap 'restore_on_exit' EXIT
        trap 'exit 143' TERM
        kill -TERM "${BASHPID}"
        sleep 2
    ) || status=$?

    [[ "${status}" -ne 0 ]] \
        || fail "SIGTERM during restore was reported as success."

    [[ -d "${rollback}" ]] \
        || fail "SIGTERM removed the rollback snapshot."

    [[ "$(cat "${live}/data/icon.txt")" == "original" ]] \
        || fail "SIGTERM left the destructive file change in place."

    rm -rf "${work}"

    ok "SIGTERM during the destructive phase kept the snapshot and restored the file."
}
