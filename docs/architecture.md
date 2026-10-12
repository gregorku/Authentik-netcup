# Architecture

Server and worker use the same pinned Authentik image; PostgreSQL and Redis are
private Compose services. Only the server publishes `10.10.10.100:9000`.
Docker allocates the internal network because its available subnets were not
verified in this checkout. Persistent state is under `DATA_DIR`.

Embedded Proxy Outpost is used. It runs in the server and routes
`/outpost.goauthentik.io/` on port 9000; no standalone proxy is deployed.
