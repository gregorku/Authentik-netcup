#!/usr/bin/env bash
set -Eeuo pipefail
stack=/docker-data/stacks/authentik-netcup; env="$stack/.env"; source "$env"
[[ -n "${BACKUP_DESTINATION:-}" ]] || { echo 'BACKUP_DESTINATION is unset: no off-container backup was made.' >&2; exit 1; }
command -v rsync >/dev/null
stamp="$(date -u +%Y%m%dT%H%M%SZ)"; work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
docker compose --env-file "$env" -f "$stack/compose.yml" exec -T postgresql pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc >"$work/postgresql.dump"
tar -C "$DATA_DIR" -czf "$work/authentik-data.tgz" media custom-templates certs blueprints
(cd "$work" && sha256sum postgresql.dump authentik-data.tgz > SHA256SUMS)
printf 'created_utc=%s\nauthentik_version=%s\npostgres_version=%s\n' "$(date -u +%FT%TZ)" "$AUTHENTIK_VERSION" "$POSTGRES_VERSION" >"$work/MANIFEST"
mkdir -p "$BACKUP_DESTINATION/$stamp"; rsync -a "$work/" "$BACKUP_DESTINATION/$stamp/"
echo "Backup copied outside the container: $BACKUP_DESTINATION/$stamp"
