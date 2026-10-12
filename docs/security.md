# Security

Generate secrets once in the runtime `.env`; do not commit or rotate them
without a recovery plan. The IP-bound port is not a firewall: Infrastructure
must restrict allowed source addresses. Keep trusted proxy CIDRs empty until
the actual proxy source is known. Enable MFA for administrators and test
recovery before relying on the service.
