#!/usr/bin/env bash
init_directories() {
    ensure_directory "${DATA_DIR}"
    local dir
    for dir in postgresql redis media custom-templates certs blueprints; do
        ensure_directory "${DATA_DIR}/${dir}"
    done
}
