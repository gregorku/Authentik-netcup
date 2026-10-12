# Authentik-netcup

Versioned Authentik stack for the existing Incus container `10.10.10.100`.
Git checkout: `/incus-dir/git/Authentik-netcup`; Dockge runtime stack:
`/docker-data/stacks/authentik-netcup`; persistent data:
`/docker-data/authentik-netcup`.

```bash
./scripts/init.sh
cp .env.example /docker-data/stacks/authentik-netcup/.env
# edit the runtime file and generate both secrets
./scripts/deploy.sh             # sync, validate, pull only
./scripts/deploy.sh --apply     # explicit deployment
./scripts/test.sh
```

The runtime `.env` is intentionally not versioned or overwritten. The only
published service port is `10.10.10.100:9000`; PostgreSQL and Redis remain
internal. See `docs/` before connecting Traefik or running a backup.
