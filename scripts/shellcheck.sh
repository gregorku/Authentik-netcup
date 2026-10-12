#!/usr/bin/env bash

###############################################################################
#
# Monitoring-netcup Project
#
# File:
#   scripts/shellcheck.sh
#
# Description:
#   Run ShellCheck on all project shell scripts.
#
###############################################################################

set -euo pipefail

if command -v shellcheck >/dev/null; then find scripts -type f -name '*.sh' -print0 | xargs -0 shellcheck -x -e SC1091,SC2034; else echo 'SKIP: shellcheck is not installed.'; fi
exit 0

echo "Running ShellCheck..."

find scripts -name "*.sh" -print0 |
xargs -0 shellcheck \
    -x \
    -e SC1091 \
    -e SC2034

echo
echo "[ OK ] ShellCheck completed."
