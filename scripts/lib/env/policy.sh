#!/usr/bin/env bash
declare -gA ENV_POLICY=(
    [COMPOSE_PROJECT_NAME]=repository [DATA_DIR]=repository
    [AUTHENTIK_HOST_IP]=repository [AUTHENTIK_HTTP_PORT]=repository
    [AUTHENTIK_VERSION]=repository [POSTGRES_VERSION]=repository [REDIS_VERSION]=repository
    [LOG_MAX_SIZE]=repository [LOG_MAX_FILES]=repository
    [AUTHENTIK_SECRET_KEY]=generated [POSTGRES_PASSWORD]=generated
    [POSTGRES_DB]=user [POSTGRES_USER]=user [AUTHENTIK_HOST]=user
    [AUTHENTIK_EMAIL__HOST]=user [AUTHENTIK_EMAIL__PORT]=user
    [AUTHENTIK_EMAIL__USERNAME]=user [AUTHENTIK_EMAIL__PASSWORD]=generated
    [AUTHENTIK_EMAIL__USE_TLS]=user [AUTHENTIK_EMAIL__FROM]=user
    [AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS]=user
    [BACKUP_DESTINATION]=user [BACKUP_RETENTION_DAYS]=user
)
env_variable_policy() { printf '%s\n' "${ENV_POLICY[$1]:-user}"; }
env_is_known_variable() { [[ -v ENV_POLICY[$1] ]]; }
