#!/usr/bin/env bash
set -Eeuo pipefail
if command -v shellcheck >/dev/null; then find scripts -type f -name '*.sh' -print0 | xargs -0 shellcheck -x -e SC1091,SC2034; else echo 'SKIP: ShellCheck is not installed.'; fi
