#!/usr/bin/env bash

###############################################################################
#
# Authentik-netcup Project
#
# Prepare persistent directories that are not part of the Git checkout
# and not part of the synchronized stack.
#
###############################################################################

init_directories()
{
    log_step "Project directories"

    ensure_directory "${DATA_DIR}"
    ensure_directory "${BACKUP_LOCAL_DIR}"

    chmod 700 "${BACKUP_LOCAL_DIR}"

    ok "Permissions 700: ${BACKUP_LOCAL_DIR}"

    log_success "Project directories ready."
}
