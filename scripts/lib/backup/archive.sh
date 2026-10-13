#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# File:
#   scripts/lib/backup/archive.sh
#
# Description:
#   Build and verify a backup directory.
#
#   The manifest lists sha256 checksums of every file except itself.
#   backup.sh also writes a sidecar checksum of the tar archive.
#   These functions do not talk to Docker and do not read DATA_DIR,
#   so the static tests can run them on a temporary directory.
#
###############################################################################

###############################################################################
# Write manifest.txt into a prepared stage directory
#
# Arguments:
#   $1 - Stage directory
#   $2 - UTC timestamp
#   $3 - Authentik image
#   $4 - Authentik tag
#   $5 - PostgreSQL image
#
###############################################################################

backup_write_manifest()
{
    local stage="$1"
    local created_at="$2"
    local authentik_image="$3"
    local authentik_tag="$4"
    local postgres_image="$5"
    local manifest="${stage}/manifest.txt"
    local path
    local hash
    local relative

    [[ -d "${stage}" ]] \
        || fail "Backup stage is not a directory: ${stage}"

    {
        printf 'project=%s\n' "${PROJECT_NAME}"
        printf 'created_at=%s\n' "${created_at}"
        printf 'authentik_image=%s\n' "${authentik_image}"
        printf 'authentik_tag=%s\n' "${authentik_tag}"
        printf 'postgres_image=%s\n' "${postgres_image}"
        printf 'database_format=custom\n'
        printf 'database_file=postgresql/authentik.dump\n'
    } > "${manifest}"

    while IFS= read -r -d '' path
    do
        [[ "${path}" == "${manifest}" ]] && continue

        hash="$(sha256sum "${path}" | awk '{print $1}')"
        relative="${path#"${stage}/"}"

        printf 'file %s %s\n' "${hash}" "${relative}" >> "${manifest}"

    done < <(find "${stage}" -type f -print0)

    ok "Manifest written."
}

###############################################################################
# Verify checksums recorded in a stage directory
#
# Arguments:
#   $1 - Stage directory
#
###############################################################################

backup_verify_tree()
{
    local stage="$1"
    local manifest="${stage}/manifest.txt"
    local record
    local hash
    local path
    local actual
    local project=""
    local files=0

    [[ -f "${manifest}" ]] \
        || fail "Manifest is missing: ${manifest}"

    while IFS= read -r line || [[ -n "${line}" ]]
    do
        [[ -z "${line}" || "${line}" == \#* ]] && continue

        if [[ "${line}" == project=* ]]; then
            project="${line#project=}"
            continue
        fi

        #
        # config.sh sets IFS to newline and tab, so read does not split
        # this line on spaces. Peel the hash and the path apart directly.
        #

        [[ "${line}" == file\ * ]] || continue

        record="${line#file }"
        hash="${record%% *}"
        path="${record#* }"

        [[ -n "${hash}" && -n "${path}" && "${hash}" != "${path}" ]] \
            || fail "Manifest entry is not a file record."

        [[ -f "${stage}/${path}" ]] \
            || fail "Manifest file is missing: ${path}"

        actual="$(sha256sum "${stage}/${path}" | awk '{print $1}')"

        [[ "${actual}" == "${hash}" ]] \
            || fail "Checksum mismatch: ${path}"

        files=$((files + 1))

    done < "${manifest}"

    [[ "${project}" == "${PROJECT_NAME}" ]] \
        || fail "Manifest project is '${project}', expected '${PROJECT_NAME}'."

    [[ "${files}" -gt 0 ]] \
        || fail "Manifest does not list any files."

    ok "Manifest checksums match (${files} files)."
}

###############################################################################
# Read one manifest field
#
# Arguments:
#   $1 - Manifest file
#   $2 - Field name
#
###############################################################################

backup_manifest_field()
{
    local manifest="$1"
    local field="$2"
    local line

    while IFS= read -r line || [[ -n "${line}" ]]
    do
        [[ "${line}" == "${field}="* ]] || continue
        printf '%s\n' "${line#"${field}="}"
        return 0
    done < "${manifest}"

    fail "Manifest field is missing: ${field}"
}

###############################################################################
# Pack a stage directory and write a sidecar checksum
#
# Arguments:
#   $1 - Stage directory
#   $2 - Archive path (.tar.gz)
#
###############################################################################

backup_pack_stage()
{
    local stage="$1"
    local archive="$2"
    local directory
    local base

    [[ -d "${stage}" ]] \
        || fail "Backup stage is not a directory: ${stage}"

    directory="$(dirname "${archive}")"
    base="$(basename "${archive}")"

    tar -C "${stage}" -czf "${archive}" .

    #
    # Store the basename. An absolute path in the sidecar would not
    # match after the archive is copied to BACKUP_EXTERNAL_DIR.
    #

    (
        cd "${directory}" || exit 1
        sha256sum "${base}" > "${base}.sha256"
    )

    chmod 600 "${archive}" "${archive}.sha256"

    ok "Archive written: ${archive}"
}

###############################################################################
# Verify an archive, its sidecar checksum and its manifest
#
# Arguments:
#   $1 - Archive path
#   $2 - Directory where the archive will be extracted
#
###############################################################################

backup_verify_archive()
{
    local archive="$1"
    local destination="$2"

    [[ -f "${archive}" ]] \
        || fail "Archive not found: ${archive}"

    [[ -f "${archive}.sha256" ]] \
        || fail "Archive checksum not found: ${archive}.sha256"

    (
        cd "$(dirname "${archive}")" || exit 1
        sha256sum --check "$(basename "${archive}").sha256" >/dev/null
    ) || fail "Archive checksum does not match ${archive}."

    mkdir -p "${destination}"

    tar -C "${destination}" -xzf "${archive}"

    backup_verify_tree "${destination}"
}
