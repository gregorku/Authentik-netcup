# Operations

`deploy.sh` validates, synchronizes and pulls but changes no containers unless
passed `--apply`. `reload.sh --apply` recreates server/worker and can interrupt
sessions. Review Authentik release notes and take a verified backup before any
version upgrade; an image downgrade is unsafe without a matching database restore.
