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
# The archive contains:
#   - a custom-format pg_dump of the Authentik database
#   - Authentik file storage, custom templates and worker certs
#   - a copy of the runtime .env (mode 600)
#   - manifest.txt with the time, image pins and sha256 checksums
#
# The PostgreSQL data directory itself is not copied. A file copy of
# that directory would not be a consistent database backup.
#
# The archive is written to:
#   /docker-data/backups/authentik-netcup
#
# If BACKUP_EXTERNAL_DIR is set in .env, the archive and its sidecar
# checksum are copied there as well. If it is empty, the script says
# so and leaves only the local archive. It does not invent a destination
# outside the container.
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
source "${SCRIPT_DIR}/lib/backup/archive.sh"
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

    BACKUP_EXTERNAL_DIR in .env receives a copy when it is set.
    An empty value is reported as local-only. No external path is
    assumed.

    Run this inside the Incus container, as root, while PostgreSQL
    is healthy. Server and worker are stopped first so the dump and
    the file copy describe the same moment. They are started again
    only if this script stopped them. HTTP is unavailable during
    that window.

    An empty BACKUP_EXTERNAL_DIR means the archive stays on this
    Incus container. That is not a backup outside the container.

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

    if [[ -n "${verify_dir}" && -d "${verify_dir}" ]]; then
        rm -rf "${verify_dir}"
    fi

    if [[ -n "${stage}" && -d "${stage}" ]]; then
        rm -rf "${stage}"
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

stage=""
verify_dir=""
trap 'backup_on_exit' EXIT

backup_quiesce_writers

created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp="$(date -u +%Y%m%d-%H%M%S)"
stage="$(mktemp -d)"

mkdir -p \
    "${stage}/postgresql" \
    "${stage}/authentik/data" \
    "${stage}/authentik/templates" \
    "${stage}/authentik/certs"

backup_dump_postgresql "${stage}/postgresql/authentik.dump"

cp -a "${AUTHENTIK_DATA_DIR}/." "${stage}/authentik/data/"
cp -a "${AUTHENTIK_TEMPLATES_DIR}/." "${stage}/authentik/templates/"
cp -a "${AUTHENTIK_CERTS_DIR}/." "${stage}/authentik/certs/"

cp "${ENV_FILE}" "${stage}/stack.env"
chmod 600 "${stage}/stack.env"

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

archive="${BACKUP_LOCAL_DIR}/authentik-netcup-${stamp}.tar.gz"

backup_pack_stage "${stage}" "${archive}"

verify_dir="$(mktemp -d)"
backup_verify_archive "${archive}" "${verify_dir}"
restore_validate_stage "${verify_dir}"
rm -rf "${verify_dir}"
verify_dir=""

external="$(env_get BACKUP_EXTERNAL_DIR)"

if [[ -z "${external}" ]]; then

    warn "BACKUP_EXTERNAL_DIR is empty."
    warn "The archive stays only on this Incus container:"
    info "${archive}"
    warn "This is not a backup outside the container."

else

    [[ -d "${external}" ]] \
        || fail "BACKUP_EXTERNAL_DIR is not a directory: ${external}"

    backup_copy_and_verify "${archive}" "${external}"

fi

if ! backup_finish_writers; then
    warn "Archive ${archive} passed its checksum check, but Authentik was not started."
    exit 1
fi

if [[ -z "${external}" ]]; then
    print_footer "Local archive completed. It is not a backup outside this container."
else
    print_footer "Backup completed."
fi
