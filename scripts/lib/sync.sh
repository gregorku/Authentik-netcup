#!/usr/bin/env bash
# The sole authoritative Git -> runtime-stack synchronization implementation.
sync_stack() {
    local item src dst
    require_rsync
    mkdir -p "${STACK_DIR}"
    for item in "${DEPLOY_ITEMS[@]}"; do
        src="${GIT_DIR}/${item}"; dst="${STACK_DIR}/${item}"
        require_file_or_directory "${src}"
        if [[ -d "${src}" ]]; then
            mkdir -p "${dst}"
            rsync -a --delete "${src}/" "${dst}/"
        else
            install -Dm644 "${src}" "${dst}"
        fi
    done
    # .env is intentionally absent from DEPLOY_ITEMS and is never touched.
}
