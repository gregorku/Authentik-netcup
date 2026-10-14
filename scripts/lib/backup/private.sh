#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# File:
#   scripts/lib/backup/private.sh
#
# Description:
#   Create and remove backup files without a world-readable window.
#
#   install -m sets the mode at creation. A later chmod is not the
#   only protection. Callers still set umask 077 before they write
#   secrets.
#
###############################################################################

###############################################################################
# Create an empty file that is readable only by its owner
#
# Arguments:
#   $1 - Path
#
###############################################################################

backup_create_private_file()
{
    local path="$1"

    install -m 600 /dev/null "${path}"
}

###############################################################################
# Create a directory that is not traversable by group or others
#
# Arguments:
#   $1 - Path
#
###############################################################################

backup_create_private_dir()
{
    local path="$1"

    mkdir -m 700 -p "${path}"
}

###############################################################################
# Copy one tree as owner-only files
#
# Arguments:
#   $1 - Source directory
#   $2 - Destination directory
#
# The destination is created as mode 700. Files are installed as mode
# 600. This is used for the rollback snapshot and for restored trees.
#
###############################################################################

backup_copy_private_tree()
{
    local source="$1"
    local dest="$2"
    local path
    local relative
    local parent

    [[ -d "${source}" ]] || return 1

    backup_create_private_dir "${dest}" || return 1

    while IFS= read -r -d '' path
    do
        relative="${path#"${source}/"}"
        parent="$(dirname "${relative}")"

        if [[ "${parent}" != "." ]]; then
            backup_create_private_dir "${dest}/${parent}" || return 1
        fi

        backup_create_private_file "${dest}/${relative}" || return 1
        cp "${path}" "${dest}/${relative}" || return 1

    done < <(find "${source}" -type f -print0)

    while IFS= read -r -d '' path
    do
        relative="${path#"${source}/"}"

        [[ -n "${relative}" ]] || continue

        backup_create_private_dir "${dest}/${relative}" || return 1

    done < <(find "${source}" -type d -print0)
}

###############################################################################
# Wipe one file and unlink it
#
# Arguments:
#   $1 - Path
#
# shred overwrites the file when it is installed. Without shred the
# file is only unlinked. The caller must not treat that as a wipe.
#
###############################################################################

backup_destroy_file()
{
    local path="$1"

    [[ -e "${path}" ]] || return 0

    if command -v shred >/dev/null 2>&1; then
        shred -u -n 1 -- "${path}" || return 1
        return 0
    fi

    rm -f -- "${path}"
}

###############################################################################
# Wipe files under a directory and remove the directory
#
# Arguments:
#   $1 - Directory
#
# A missing path is success. A failed wipe is failure so the caller
# does not report a completed backup or restore.
#
###############################################################################

backup_destroy_tree()
{
    local root="$1"
    local path

    [[ -n "${root}" ]] || return 0
    [[ -e "${root}" ]] || return 0

    while IFS= read -r -d '' path
    do
        backup_destroy_file "${path}" || return 1

    done < <(find "${root}" -type f -print0)

    rm -rf -- "${root}"
}

###############################################################################
# Remove a plaintext tree or refuse to call the run complete
#
# Arguments:
#   $1 - Directory
#
###############################################################################

backup_discard_plaintext()
{
    local path="$1"

    if backup_destroy_tree "${path}"; then
        return 0
    fi

    warn "Plaintext archive could not be removed: ${path}. This run is not a completed backup."
    return 1
}
