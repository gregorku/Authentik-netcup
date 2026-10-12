# Traefik contract

Infrastructure-netcup owns DNS, ACME/TLS, firewall, and Traefik. Its proposed
backend is `http://10.10.10.100:9000` for `auth.serveftp.org`; it must route
`/outpost.goauthentik.io/` to the same backend. DNS, certificate issuance,
HTTP-01, HAProxy forwarding and allowed source IPs are **unverified**.

Before enabling it, set the embedded outpost's full `https://auth.serveftp.org`
host in Authentik, determine the source CIDR actually visible to Authentik, and
then set `AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS`. Do not alter the existing
BasicAuth default-chain. Metabase must get a separate ForwardAuth chain; never
combine BasicAuth and ForwardAuth as one required path. Roll back by removing
that new router/middleware and restoring the prior Metabase routing.
