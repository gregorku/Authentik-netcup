#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# File:
#   scripts/backup.sh
#
# Description:
#   Create a consistent backup of Authentik and PostgreSQL.
#
# Usage:
#   ./scripts/backup.sh
#   ./scripts/backup.sh --help
#
# The encrypted archive contains:
#   - a custom-format pg_dump of the Authentik database
#   - Authentik file storage, custom templates and worker certs
#   - a copy of the runtime .env
#   - manifest.txt with the time, image pins and sha256 checksums
#
# The kept file is name.tar.gz.age. age encrypts it to
# BACKUP_AGE_RECIPIENT. The private identity is not in this script,
# in Git, or in the stack. The sidecar checksum is of the .age file.
#
# The PostgreSQL data directory itself is not copied. A file copy of
# that directory would not be a consistent database backup.
#
# The archive is written to:
#   /docker-data/backups/authentik-netcup
#
# If BACKUP_EXTERNAL_DIR is set, the encrypted archive is copied only
# when that directory is mode 700 and on another filesystem. A copy
# on another filesystem is still not proof of storage outside this
# Incus container. An empty value leaves only the local encrypted
# archive. Without age or a public recipient, no archive is kept.
#
# Side effects:
#   - Stops authentik-server and authentik-worker when they are running,
#     then starts only those this script stopped
#   - HTTP on 10.10.10.100:9000 is down for the dump and the file copy
#   - Reads the running PostgreSQL container
#   - Writes a new archive under BACKUP_LOCAL_DIR
#   - Does not modify DATA_DIR
#
# Next step:
#   Keep the archive with the same AUTHENTIK_TAG. See
#   docs/backup-restore.md before restore.sh.
#
###############################################################################

set -Eeuo pipefail

#
# Owner-only files from the first redirect, before any secret exists.
#

umask 077

###############################################################################
# Directories
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Configuration
###############################################################################

source "${SCRIPT_DIR}/config.sh"

###############################################################################
# Libraries
###############################################################################

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/filesystem.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/checks/load.sh"
source "${SCRIPT_DIR}/lib/env/load.sh"
source "${SCRIPT_DIR}/lib/backup/private.sh"
source "${SCRIPT_DIR}/lib/backup/archive.sh"
source "${SCRIPT_DIR}/lib/backup/crypto.sh"
source "${SCRIPT_DIR}/lib/backup/postgres.sh"
source "${SCRIPT_DIR}/lib/backup/restore-plan.sh"
source "${SCRIPT_DIR}/lib/backup/runtime.sh"

###############################################################################
# Help
###############################################################################

show_help()
{
cat <<EOF
Authentik-netcup Project

Usage:

    ./scripts/backup.sh
    ./scripts/backup.sh --help

Description:

    Dump PostgreSQL, copy Authentik persistent files and write a
    checksummed archive to:

        ${BACKUP_LOCAL_DIR}

    rsync --delete never sees this directory. It is not a DEPLOY_ITEMS
    path and it is not inside the runtime stack.

    BACKUP_AGE_RECIPIENT is the public age recipient. Without it, or
    without the age command, no archive is written.

    BACKUP_EXTERNAL_DIR receives an encrypted copy only when it is
    mode 700 and on a different filesystem from the local backup
    directory. That copy is not described as storage outside this
    Incus container. The script cannot see the host mount table.

    An empty BACKUP_EXTERNAL_DIR leaves the encrypted archive only
    on this container.

    Run this inside the Incus container, as root, while PostgreSQL
    is healthy. Server and worker are stopped first so the dump and
    the file copy describe the same moment. They are started again
    only if this script stopped them. HTTP is unavailable during
    that window.

EOF
}

###############################################################################
# Main
###############################################################################

case "${1:-}" in

    "")
        ;;

    -h|--help)
        show_help
        exit 0
        ;;

    *)
        fail "Unknown option: ${1}"
        ;;

esac

###############################################################################
# Remove the stage and start containers this backup stopped
###############################################################################

backup_on_exit()
{
    local status=$?

    trap - EXIT INT TERM HUP

    if [[ -n "${verify_dir}" ]]; then
        backup_destroy_tree "${verify_dir}" || status=1
    fi

    if [[ -n "${plain_dir}" ]]; then
        if ! backup_destroy_tree "${plain_dir}"; then
            warn "Plaintext archive could not be removed: ${plain_dir}."
            status=1
        fi
    fi

    if [[ -n "${stage}" ]]; then
        backup_destroy_tree "${stage}" || status=1
    fi

    if ! backup_finish_writers; then
        warn "Authentik was not started again."

        if [[ "${status}" -eq 0 ]]; then
            status=1
        fi
    fi

    exit "${status}"
}

print_header "Authentik-netcup backup"

check_environment
check_docker_environment

[[ -f "${ENV_FILE}" ]] \
    || fail ".env not found. Run ./scripts/update-env.sh"

env_validate

require_directory "${AUTHENTIK_DATA_DIR}"
require_directory "${AUTHENTIK_TEMPLATES_DIR}"
require_directory "${AUTHENTIK_CERTS_DIR}"

backup_require_postgresql

backup_require_encryption "$(env_get BACKUP_AGE_RECIPIENT)"

stage=""
verify_dir=""
plain_dir=""
trap 'backup_on_exit' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP

backup_quiesce_writers

created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp="$(date -u +%Y%m%d-%H%M%S)"
stage="$(mktemp -d)"

backup_create_private_dir "${stage}/postgresql"
backup_create_private_dir "${stage}/authentik"

backup_dump_postgresql "${stage}/postgresql/authentik.dump"

backup_copy_private_tree "${AUTHENTIK_DATA_DIR}" "${stage}/authentik/data"
backup_copy_private_tree "${AUTHENTIK_TEMPLATES_DIR}" "${stage}/authentik/templates"
backup_copy_private_tree "${AUTHENTIK_CERTS_DIR}" "${stage}/authentik/certs"

install -m 600 "${ENV_FILE}" "${stage}/stack.env"

authentik_image="$(env_get AUTHENTIK_IMAGE)"
authentik_tag="$(env_get AUTHENTIK_TAG)"
postgres_image="$(env_get POSTGRES_IMAGE)"

backup_write_manifest \
    "${stage}" \
    "${created_at}" \
    "${authentik_image}" \
    "${authentik_tag}" \
    "${postgres_image}"

restore_validate_stage "${stage}"

ensure_directory "${BACKUP_LOCAL_DIR}"
chmod 700 "${BACKUP_LOCAL_DIR}"

plain_dir="$(mktemp -d)"
plain="${plain_dir}/plain.tar.gz"
backup_create_private_file "${plain}"
tar -C "${stage}" -czf "${plain}" .

verify_dir="$(mktemp -d)"
tar -C "${verify_dir}" -xzf "${plain}"
restore_validate_stage "${verify_dir}"

if ! backup_destroy_tree "${verify_dir}"; then
    verify_dir=""
    fail "Could not remove the plaintext verification directory. No encrypted archive was kept."
fi

verify_dir=""

archive="${BACKUP_LOCAL_DIR}/authentik-netcup-${stamp}.tar.gz.age"

if ! backup_encrypt_file "${plain}" "${archive}" "$(env_get BACKUP_AGE_RECIPIENT)"; then
    backup_destroy_file "${archive}" || true
    fail "Encryption failed. No archive was kept. This run is not a safe external backup."
fi

backup_write_checksum "${archive}"
backup_require_sidecar "${archive}" "archive"

if ! backup_discard_plaintext "${plain_dir}"; then
    exit 1
fi

plain_dir=""

external="$(env_get BACKUP_EXTERNAL_DIR)"

if [[ -z "${external}" ]]; then

    warn "BACKUP_EXTERNAL_DIR is empty."
    warn "The encrypted archive stays only on this Incus container:"
    info "${archive}"
    warn "This is not a backup outside the container."

else

    backup_publish_encrypted "${archive}" "${external}" "${BACKUP_LOCAL_DIR}"

fi

if ! backup_finish_writers; then
    warn "Encrypted archive ${archive} passed its checksum check, but Authentik was not started."
    exit 1
fi

if [[ -z "${external}" ]]; then
    print_footer "Encrypted local archive completed. It is not a backup outside this container."
else
    print_footer "Encrypted copy verified on another filesystem. Not a confirmed backup outside this container."
fi
