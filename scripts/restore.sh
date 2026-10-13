#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# File:
#   scripts/restore.sh
#
# Description:
#   Restore an Authentik backup over the persistent data of this stack.
#
# Usage:
#   ./scripts/restore.sh --archive PATH --confirm authentik-netcup
#   ./scripts/restore.sh --archive PATH --confirm authentik-netcup --replace-data
#   ./scripts/restore.sh --help
#
# Without --replace-data the archive and manifest are verified and
# nothing is written. Exit status is then 2.
#
# With --replace-data the required runtime state is:
#   - authentik-server is stopped
#   - authentik-worker is stopped
#   - authentik-postgresql is running and healthy
#
# Order of writes:
#   1. Replace Authentik data, templates and certs.
#   2. pg_restore into the running PostgreSQL.
#
# The runtime .env is not replaced automatically. stack.env inside the
# archive is the secret key and passwords from the backup. The manifest
# tag must match AUTHENTIK_TAG unless --allow-version-mismatch is set.
# Restoring a database that was written by a different Authentik
# version can fail migrations or leave the schema incompatible.
#
# Side effects with --replace-data:
#   - Deletes and replaces the three Authentik data directories
#   - Drops and recreates objects in the Authentik database
#
# This script does not start Compose and does not change Traefik.
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

###############################################################################
# Help
###############################################################################

show_help()
{
cat <<EOF
Authentik-netcup Project

Usage:

    ./scripts/restore.sh --archive PATH --confirm ${STACK_NAME}
    ./scripts/restore.sh --archive PATH --confirm ${STACK_NAME} --replace-data
    ./scripts/restore.sh --help

Options:

    --archive PATH
        Backup tar.gz produced by backup.sh. The sidecar PATH.sha256
        has to sit next to it.

    --confirm ${STACK_NAME}
        Required. Any other value is refused.

    --replace-data
        Overwrite Authentik files and the PostgreSQL database.
        Without this option the archive is only verified.

    --allow-version-mismatch
        Restore even when the manifest tag differs from AUTHENTIK_TAG.
        The database and the running image can then be incompatible.

Required state before --replace-data:

    Stop ${AUTHENTIK_SERVER_CONTAINER} and ${AUTHENTIK_WORKER_CONTAINER}.
    Leave ${POSTGRESQL_CONTAINER} running and healthy.
    Keep AUTHENTIK_TAG equal to the manifest unless the mismatch
    flag is set.

EOF
}

###############################################################################
# Arguments
###############################################################################

archive=""
confirm=""
replace_data="no"
allow_mismatch="no"

while [[ $# -gt 0 ]]
do
    case "$1" in

        --archive)
            [[ $# -ge 2 ]] || fail "--archive requires a path."
            archive="$2"
            shift 2
            ;;

        --confirm)
            [[ $# -ge 2 ]] || fail "--confirm requires the stack name."
            confirm="$2"
            shift 2
            ;;

        --replace-data)
            replace_data="yes"
            shift
            ;;

        --allow-version-mismatch)
            allow_mismatch="yes"
            shift
            ;;

        -h|--help)
            show_help
            exit 0
            ;;

        *)
            fail "Unknown option: $1"
            ;;

    esac
done

[[ -n "${archive}" ]] \
    || fail "--archive is required."

restore_confirmation_matches "${confirm}" \
    || fail "Refusing restore. --confirm must be exactly '${STACK_NAME}'."

print_header "Authentik-netcup restore"

check_environment

stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT

backup_verify_archive "${archive}" "${stage}"

manifest="${stage}/manifest.txt"
manifest_tag="$(backup_manifest_field "${manifest}" authentik_tag)"

[[ -f "${ENV_FILE}" ]] \
    || fail ".env not found. The restore target is not initialized."

runtime_tag="$(env_get AUTHENTIK_TAG)"

if ! restore_versions_match "${manifest_tag}" "${runtime_tag}" "${allow_mismatch}"; then
    fail "Manifest Authentik tag is ${manifest_tag}; .env has ${runtime_tag}. Database and image must match, or pass --allow-version-mismatch."
fi

if [[ "${replace_data}" != "yes" ]]; then
    warn "Archive verified. Persistent data was not changed."
    warn "Re-run with --replace-data to overwrite Authentik files and PostgreSQL."
    exit 2
fi

check_docker_environment

if docker_container_running "${AUTHENTIK_SERVER_CONTAINER}"; then
    fail "Stop ${AUTHENTIK_SERVER_CONTAINER} before restore."
fi

if docker_container_running "${AUTHENTIK_WORKER_CONTAINER}"; then
    fail "Stop ${AUTHENTIK_WORKER_CONTAINER} before restore."
fi

backup_require_postgresql

info "Replacing Authentik files, then restoring PostgreSQL."

rm -rf \
    "${AUTHENTIK_DATA_DIR}" \
    "${AUTHENTIK_TEMPLATES_DIR}" \
    "${AUTHENTIK_CERTS_DIR}"

mkdir -p \
    "${AUTHENTIK_DATA_DIR}" \
    "${AUTHENTIK_TEMPLATES_DIR}" \
    "${AUTHENTIK_CERTS_DIR}"

cp -a "${stage}/authentik/data/." "${AUTHENTIK_DATA_DIR}/"
cp -a "${stage}/authentik/templates/." "${AUTHENTIK_TEMPLATES_DIR}/"
cp -a "${stage}/authentik/certs/." "${AUTHENTIK_CERTS_DIR}/"

chown -R "${AUTHENTIK_UID_GID}" \
    "${AUTHENTIK_DATA_DIR}" \
    "${AUTHENTIK_TEMPLATES_DIR}" \
    "${AUTHENTIK_CERTS_DIR}"

backup_restore_postgresql "${stage}/postgresql/authentik.dump"

info "stack.env in the archive was not copied over ${ENV_FILE}."
info "Compare it with the runtime .env before starting Authentik."
info "Start the stack only with Authentik tag ${manifest_tag}."

print_footer "Restore completed."
