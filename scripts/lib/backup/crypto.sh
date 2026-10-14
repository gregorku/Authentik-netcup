#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# File:
#   scripts/lib/backup/crypto.sh
#
# Description:
#   Encrypt a backup with age and decrypt it for restore.
#
#   BACKUP_AGE_RECIPIENT is a public recipient. The private identity
#   is not stored in Git, in the archive, or in the stack. age reads
#   the identity from a file descriptor so the key material is not a
#   process argument.
#
#   The published checksum belongs to the encrypted file. tar writes
#   to stdout and age reads that stream. No plaintext tar file is
#   created. The private identity is not used here, so the .age file
#   cannot be decrypted to repeat the stage check.
#
###############################################################################

###############################################################################
# Public recipient, not an age identity
#
# Arguments:
#   $1 - Recipient
#
###############################################################################

backup_recipient_is_public()
{
    local recipient="$1"

    [[ -n "${recipient}" ]] || return 1

    [[ "${recipient}" != *$'\n'* ]] || return 1

    [[ "${recipient}" != AGE-SECRET-KEY-* ]] || return 1

    if [[ "${recipient}" == age1* ]]; then
        [[ "${recipient}" =~ ^age1[a-z0-9]+$ ]]
        return
    fi

    [[ "${recipient}" =~ ^ssh-(ed25519|rsa)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]]+[^[:space:]]+)?$ ]]
}

###############################################################################
# Refuse to keep an archive when encryption is not available
#
# Arguments:
#   $1 - BACKUP_AGE_RECIPIENT
#
# Failure means no durable archive was written. The run is not a safe
# external backup.
#
###############################################################################

backup_require_encryption()
{
    local recipient="$1"

    if [[ -z "${recipient}" ]]; then
        fail "BACKUP_AGE_RECIPIENT is empty. No archive was kept. This run is not a safe external backup."
    fi

    if ! backup_recipient_is_public "${recipient}"; then
        fail "BACKUP_AGE_RECIPIENT is not a public age recipient. No archive was kept. This run is not a safe external backup."
    fi

    if ! command -v age >/dev/null 2>&1; then
        fail "age is not installed. No archive was kept. This run is not a safe external backup."
    fi
}

###############################################################################
# Encrypt a plaintext archive
#
# Arguments:
#   $1 - Plaintext archive
#   $2 - Destination .age path
#   $3 - Public recipient
#
# The destination is created mode 600 before age writes it. The
# recipient is public. It is not written to the log.
#
###############################################################################

backup_encrypt_file()
{
    local plain="$1"
    local encrypted="$2"
    local recipient="$3"

    [[ -f "${plain}" ]] || return 1

    backup_recipient_is_public "${recipient}" || return 1

    command -v age >/dev/null 2>&1 || return 1

    backup_create_private_file "${encrypted}" || return 1

    age -r "${recipient}" -o "${encrypted}" "${plain}" >/dev/null
}

###############################################################################
# Encrypt a stage directory without writing a plaintext tar
#
# Arguments:
#   $1 - Stage directory
#   $2 - Destination .age path
#   $3 - Public recipient
#
# tar and age run in one pipeline. pipefail is enabled so a tar
# failure is not hidden when age exits 0. The destination is created
# mode 600 before age writes it. On failure that file is removed.
# The private identity is not an argument.
#
###############################################################################

backup_encrypt_stage()
{
    local stage="$1"
    local encrypted="$2"
    local recipient="$3"

    [[ -d "${stage}" ]] || return 1

    backup_recipient_is_public "${recipient}" || return 1

    command -v age >/dev/null 2>&1 || return 1
    command -v tar >/dev/null 2>&1 || return 1

    backup_create_private_file "${encrypted}" || return 1

    #
    # pipefail is a shell option, not a local one. Leaving it on keeps
    # a later pipeline from hiding a producer failure.
    #

    set -o pipefail

    if ! tar -C "${stage}" -czf - . \
        | age -r "${recipient}" -o "${encrypted}" >/dev/null
    then
        backup_destroy_file "${encrypted}" || true
        return 1
    fi

    if [[ ! -s "${encrypted}" ]]; then
        backup_destroy_file "${encrypted}" || true
        return 1
    fi
}

###############################################################################
# Remove a failed ciphertext and any final path already copied
#
# Arguments:
#   $1 - Final .age path
#   $2 - Temporary directory
#
###############################################################################

backup_drop_encrypted_attempt()
{
    local final="$1"
    local pending_dir="$2"

    backup_destroy_file "${final}" || true
    backup_destroy_file "${final}.sha256" || true
    backup_destroy_tree "${pending_dir}" || true
}

###############################################################################
# Publish one encrypted archive after its checksum matches
#
# Arguments:
#   $1 - Stage directory
#   $2 - Final .age path
#   $3 - Public recipient
#   $4 - Private directory for the temporary ciphertext
#
# The final path is written only after the pipeline and the checksum
# of that ciphertext both succeed. A failure deletes the final path
# and the temporary ciphertext. Return 2 means the final file passed
# its checksum and the temporary directory could not be removed.
#
###############################################################################

backup_store_encrypted_stage()
{
    local stage="$1"
    local final="$2"
    local recipient="$3"
    local pending_dir="$4"
    local pending="${pending_dir}/stream.tar.gz.age"
    local pending_hash
    local final_hash

    [[ -d "${pending_dir}" ]] || return 1

    if ! backup_encrypt_stage "${stage}" "${pending}" "${recipient}"; then
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    fi

    if ! backup_write_checksum "${pending}"; then
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    fi

    if ! backup_verify_sidecar "${pending}"; then
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    fi

    if ! install -m 600 "${pending}" "${final}"; then
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    fi

    #
    # The sidecar names the file beside it. Copying the temporary
    # sidecar would still name stream.tar.gz.age. Recompute it for
    # the published name and require the same digest.
    #

    pending_hash="$(awk '{print $1; exit}' "${pending}.sha256")" || {
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    }
    final_hash="$(sha256sum "${final}" | awk '{print $1}')" || {
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    }

    if [[ -z "${pending_hash}" || "${pending_hash}" != "${final_hash}" ]]; then
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    fi

    if ! backup_write_checksum "${final}"; then
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    fi

    if ! backup_verify_sidecar "${final}"; then
        backup_drop_encrypted_attempt "${final}" "${pending_dir}"
        return 1
    fi

    if ! backup_destroy_tree "${pending_dir}"; then
        return 2
    fi
}

###############################################################################
# Decrypt an archive with an identity file
#
# Arguments:
#   $1 - Encrypted archive
#   $2 - Plaintext destination
#   $3 - Identity file
#
# The identity contents stay in the file. age reads them through
# /dev/fd so they are not placed on the command line.
#
###############################################################################

backup_decrypt_file()
{
    local encrypted="$1"
    local plain="$2"
    local identity="$3"
    local identity_fd

    [[ -f "${encrypted}" ]] || return 1
    [[ -f "${identity}" ]] || return 1

    backup_create_private_file "${plain}" || return 1

    exec {identity_fd}<"${identity}" || return 1

    if ! age -d -i "/dev/fd/${identity_fd}" -o "${plain}" "${encrypted}" >/dev/null 2>&1; then
        exec {identity_fd}<&-
        backup_destroy_file "${plain}" || true
        return 1
    fi

    exec {identity_fd}<&-
}

###############################################################################
# Identity file is owner-only and outside the project trees
#
# Arguments:
#   $1 - Identity path
#
###############################################################################

backup_path_is_forbidden()
{
    local path="$1"
    local protected

    for protected in "${DATA_DIR}" "${STACK_DIR}" "${GIT_DIR}" "${BACKUP_LOCAL_DIR}"
    do
        [[ "${path}" == "${protected}" || "${path}" == "${protected}/"* ]] \
            && return 0
    done

    return 1
}

backup_require_identity()
{
    local identity="$1"
    local resolved
    local mode

    [[ -n "${identity}" ]] \
        || fail "Restore requires --identity PATH. The age identity is not read from Git, the stack, or the archive."

    [[ -f "${identity}" ]] \
        || fail "Age identity was not found."

    resolved="$(realpath -e "${identity}")" \
        || fail "Age identity path could not be resolved."

    if backup_path_is_forbidden "${resolved}"; then
        fail "Age identity must not be stored in Git, the stack, DATA_DIR, or the local backup directory."
    fi

    mode="$(stat -c '%a' "${resolved}")" \
        || fail "Age identity mode could not be read."

    [[ "${mode}" == "600" || "${mode}" == "400" ]] \
        || fail "Age identity must be mode 600 or 400."
}

###############################################################################
# Resolved destination and how it may be described
#
# Arguments:
#   $1 - Requested directory
#   $2 - Local backup directory
#
# Prints one word to stdout:
#   same-filesystem
#   other-filesystem
#
# other-filesystem is a verified copy on another device. It is not
# proof that the device is outside the Incus container.
#
###############################################################################

backup_classify_destination()
{
    local requested="$1"
    local local_dir="$2"
    local resolved
    local mode
    local dest_device
    local local_device

    [[ -d "${requested}" ]] \
        || fail "BACKUP_EXTERNAL_DIR is not a directory: ${requested}"

    resolved="$(realpath -e "${requested}")" \
        || fail "BACKUP_EXTERNAL_DIR could not be resolved: ${requested}"

    BACKUP_RESOLVED_DEST="${resolved}"

    env_validate_backup_target "${resolved}"

    mode="$(stat -c '%a' "${resolved}")" \
        || fail "BACKUP_EXTERNAL_DIR mode could not be read."

    [[ "${mode}" == "700" ]] \
        || fail "BACKUP_EXTERNAL_DIR must be mode 700. Refusing to copy the archive to ${resolved}."

    [[ "$(stat -c '%u' "${resolved}")" == "$(id -u)" ]] \
        || fail "BACKUP_EXTERNAL_DIR must be owned by the user running backup.sh."

    dest_device="$(stat -c '%d' "${resolved}")" \
        || fail "BACKUP_EXTERNAL_DIR device could not be read."

    local_device="$(stat -c '%d' "${local_dir}")" \
        || fail "Local backup directory device could not be read."

    if [[ "${dest_device}" == "${local_device}" ]]; then
        printf '%s\n' "same-filesystem"
        return 0
    fi

    printf '%s\n' "other-filesystem"
}

###############################################################################
# Copy an encrypted archive, or refuse a same-filesystem destination
#
# Arguments:
#   $1 - Encrypted archive
#   $2 - Requested destination directory
#   $3 - Local backup directory
#
# A same-filesystem path is not copied and is not called an external
# backup. A different filesystem is a verified copy only. This script
# cannot prove that the other filesystem is outside the Incus container.
#
###############################################################################

backup_publish_encrypted()
{
    local archive="$1"
    local requested="$2"
    local local_dir="$3"
    local kind

    kind="$(backup_classify_destination "${requested}" "${local_dir}")"

    case "${kind}" in

        same-filesystem)
            fail "BACKUP_EXTERNAL_DIR is on the same filesystem as ${local_dir}. The copy was not made. This is not an external backup."
            ;;

        other-filesystem)
            backup_copy_and_verify "${archive}" "${BACKUP_RESOLVED_DEST}"
            warn "Verified encrypted copy on another filesystem: ${BACKUP_RESOLVED_DEST}."
            warn "This script cannot prove that filesystem is outside the Incus container."
            ;;

        *)
            fail "Unexpected backup destination class."
            ;;

    esac
}
