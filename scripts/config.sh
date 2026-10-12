#!/usr/bin/env bash
# Shared paths. Runtime environment values are read only from STACK_DIR/.env.
readonly PROJECT_NAME=Authentik-netcup
readonly STACK_NAME=authentik-netcup
readonly GIT_DIR=/incus-dir/git/Authentik-netcup
readonly BASE_DIR=/docker-data
readonly STACK_DIR="${BASE_DIR}/stacks/${STACK_NAME}"
readonly DATA_DIR="${BASE_DIR}/${STACK_NAME}"
readonly ENV_FILE="${STACK_DIR}/.env"
readonly ENV_EXAMPLE_FILE="${STACK_DIR}/.env.example"
readonly COMPOSE_FILE="${STACK_DIR}/compose.yml"
readonly DEPLOY_ITEMS=(compose.yml compose configs .env.example)
readonly AUTHENTIK_SERVICES=(server worker postgresql redis)
