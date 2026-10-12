#!/usr/bin/env bash
set -Eeuo pipefail
backup="${1:?Usage: restore.sh /path/to/backup}"; [[ "${CONFIRM_RESTORE:-}" == RESTORE_AUTHENTIK ]] || { echo 'Set CONFIRM_RESTORE=RESTORE_AUTHENTIK to continue.' >&2; exit 2; }
stack=/docker-data/stacks/authentik-netcup
source "$stack/.env"
[[ -f "$backup/MANIFEST" && -f "$backup/SHA256SUMS" && -f "$backup/postgresql.dump" && -f "$backup/authentik-data.tgz" ]] || { echo 'Invalid backup layout' >&2; exit 1; }
(cd "$backup" && sha256sum -c SHA256SUMS)
docker compose --env-file "$stack/.env" -f "$stack/compose.yml" stop server worker
tar -C "$DATA_DIR" -xzf "$backup/authentik-data.tgz"
docker compose --env-file "$stack/.env" -f "$stack/compose.yml" exec -T postgresql pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists <"$backup/postgresql.dump"
docker compose --env-file "$stack/.env" -f "$stack/compose.yml" up -d
echo 'Restore submitted. Run post-deploy.sh and verify the UI before declaring recovery complete.'
