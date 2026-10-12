#!/usr/bin/env bash
#
###############################################################################
#
# Monitoring-netcup
#
# SNMP Exporter Builder
#
# Version : 1.1
#
###############################################################################

set -Eeuo pipefail

###############################################################################
# Configuration
###############################################################################

readonly VERSION="1.1"

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly MODULE_DIR="${SCRIPT_DIR}/modules"

readonly OUTPUT_FILE="${SCRIPT_DIR}/snmp.yml"

readonly STACK_DIR="/docker-data/stacks/monitoring-netcup/configs/snmp-exporter"

readonly STACK_FILE="${STACK_DIR}/snmp.yml"

TMP_FILE=""

###############################################################################
# Colours
###############################################################################

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1
then

    CLR_RED="$(tput setaf 1)"
    CLR_GREEN="$(tput setaf 2)"
    CLR_YELLOW="$(tput setaf 3)"
    CLR_BLUE="$(tput setaf 4)"
    CLR_RESET="$(tput sgr0)"

else

    CLR_RED=""
    CLR_GREEN=""
    CLR_YELLOW=""
    CLR_BLUE=""
    CLR_RESET=""

fi

###############################################################################
# Cleanup
###############################################################################

cleanup() {

    [[ -n "${TMP_FILE}" ]] || return

    [[ -f "${TMP_FILE}" ]] && rm -f "${TMP_FILE}"

}

trap cleanup EXIT

###############################################################################
# Logging
###############################################################################

log_info() {

    printf "%s==>%s %s\n" \
        "${CLR_BLUE}" \
        "${CLR_RESET}" \
        "$1"

}

log_ok() {

    printf "%s✔%s %s\n" \
        "${CLR_GREEN}" \
        "${CLR_RESET}" \
        "$1"

}

log_warn() {

    printf "%s⚠%s %s\n" \
        "${CLR_YELLOW}" \
        "${CLR_RESET}" \
        "$1"

}

log_error() {

    printf "%s✖%s %s\n" \
        "${CLR_RED}" \
        "${CLR_RESET}" \
        "$1" >&2

}

die() {

    log_error "$1"

    exit 1

}

###############################################################################
# Banner
###############################################################################

print_banner() {

cat <<EOF

==============================================================

 Monitoring-netcup

 SNMP Exporter Builder ${VERSION}

==============================================================

EOF

}

###############################################################################
# Help
###############################################################################

usage() {

cat <<EOF

Použití

    ./build-snmp.sh

nebo

    ./build-snmp.sh --build

Volby

    --build

        vytvoří nový snmp.yml

    --check

        zkontroluje moduly

    --list

        vypíše nalezené moduly

    --help

        zobrazí tuto nápovědu

EOF

}

###############################################################################
# Helpers
###############################################################################

require_directory() {

    [[ -d "$1" ]] || die "Adresář neexistuje: $1"

}

require_file() {

    [[ -f "$1" ]] || die "Soubor neexistuje: $1"

}

require_not_empty() {

    [[ -s "$1" ]] || die "Soubor je prázdný: $(basename "$1")"

}

###############################################################################
# Validation
###############################################################################

declare -A MODULE_NAMES

###############################################################################
# Return module name
###############################################################################

get_module_name() {

    local file="$1"

    awk '

        /^modules:/ {

            inmodules=1

            next

        }

        inmodules && /^[[:space:]][[:space:]]*[A-Za-z0-9_-]+:/ {

            sub(/^[[:space:]]+/, "")
            sub(/:.*/, "")

            print

            exit

        }

    ' "$file"

}

###############################################################################
# Check one module
###############################################################################

check_module() {

    local file="$1"

    require_file "$file"

    require_not_empty "$file"

    grep -q '^modules:' "$file" \
        || die "$(basename "$file"): chybí sekce modules:"

    local module

    module="$(get_module_name "$file")"

    [[ -n "$module" ]] \
        || die "$(basename "$file"): nelze zjistit název modulu."

    if [[ -n "${MODULE_NAMES[$module]:-}" ]]
    then

        die "Duplicitní modul: ${module}"

    fi

    MODULE_NAMES["$module"]=1

}

###############################################################################
# Check all modules
###############################################################################

check_modules() {

    require_directory "$MODULE_DIR"

    local count=0

    while IFS= read -r -d '' file
    do

        check_module "$file"

        log_ok "$(basename "$file")"

        ((++count))

    done < <(
        find "$MODULE_DIR" \
            -type f \
            -name "*.yml" \
            -print0 | sort -z
    )

    ((count>0)) \
        || die "Adresář modules je prázdný."

}

###############################################################################
# List modules
###############################################################################

list_modules() {

    printf "\n"

    printf "Moduly\n"

    printf "--------------------------------------------------\n"

    while IFS= read -r -d '' file
    do

        printf " %-25s %s\n" \
            "$(basename "$file")" \
            "$(get_module_name "$file")"

    done < <(
        find "$MODULE_DIR" \
            -type f \
            -name "*.yml" \
            -print0 | sort -z
    )

    printf "\n"

}

###############################################################################
# Build
###############################################################################

build() {

    TMP_FILE="$(mktemp "${SCRIPT_DIR}/snmp.yml.tmp.XXXXXX")"

    log_info "Generuji snmp.yml"

###############################################################################
# Header
###############################################################################

cat > "${TMP_FILE}" <<EOF
###############################################################################
#
# AUTO GENERATED FILE
#
# Monitoring-netcup
#
# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
#
# DO NOT EDIT
#
###############################################################################

EOF

###############################################################################
# auth.yml
###############################################################################

if [[ -f "${SCRIPT_DIR}/auth.yml" ]]
then
    cat "${SCRIPT_DIR}/auth.yml" >> "${TMP_FILE}"
    printf "\n" >> "${TMP_FILE}"
fi

###############################################################################
# modules
###############################################################################

printf "modules:\n\n" >> "${TMP_FILE}"

###############################################################################
# Merge modules
###############################################################################

while IFS= read -r -d '' file
do

    printf "# ------------------------------------------------------------------\n" >> "${TMP_FILE}"
    printf "# %s\n" "$(basename "$file")" >> "${TMP_FILE}"
    printf "# ------------------------------------------------------------------\n\n" >> "${TMP_FILE}"

    #
    # Přeskočí pouze první výskyt "modules:"
    #
    awk '
    BEGIN {
        skip = 1
    }

    skip && /^modules:[[:space:]]*$/ {
        skip = 0
        next
    }

    skip {
        next
    }

    {
        print
    }
    ' "$file" >> "${TMP_FILE}"

    printf "\n" >> "${TMP_FILE}"

done < <(
    find "${MODULE_DIR}" \
        -type f \
        -name "*.yml" \
        -print0 | sort -z
)

###############################################################################
# Compare
###############################################################################

if [[ -f "${OUTPUT_FILE}" ]]
then

    if cmp -s "${TMP_FILE}" "${OUTPUT_FILE}"
    then
        rm -f "${TMP_FILE}"

        log_ok "snmp.yml beze změny."

        return 0
    fi

fi

###############################################################################
# Install
###############################################################################

mv "${TMP_FILE}" "${OUTPUT_FILE}"

log_ok "Vytvořen ${OUTPUT_FILE}"

if [[ -d "${STACK_DIR}" ]]
then
    install -m 0644 "${OUTPUT_FILE}" "${STACK_FILE}"
    log_ok "Aktualizován ${STACK_FILE}"
fi

}

###############################################################################
# Summary
###############################################################################

summary() {

    printf "\n"

    printf '%s\n' '--------------------------------------------------------------'
    printf " Moduly : %s\n" "${#MODULE_NAMES[@]}"
    printf " Výstup : %s\n" "${OUTPUT_FILE}"
    printf '%s\n' '--------------------------------------------------------------'

    printf "\n"

}

###############################################################################
# Main
###############################################################################

main() {

    local action="${1:---build}"

    require_directory "${MODULE_DIR}"

    if [[ -t 1 ]]
    then
        print_banner
    fi

    case "${action}" in

        --help|-h)

            usage
            exit 0
            ;;

        --list)

            check_modules
            list_modules
            exit 0
            ;;

        --check)

            log_info "Kontroluji moduly"

            [[ -f "${SCRIPT_DIR}/auth.yml" ]] \
                || log_warn "auth.yml nenalezen."

            check_modules

            printf "\n"

            log_ok "Kontrola dokončena."

            summary

            exit 0
            ;;

        --build|build)

            log_info "Kontroluji moduly"

            check_modules

            printf "\n"

            build

            summary

            log_ok "Hotovo."

            exit 0
            ;;

        *)

            die "Neznámá volba: ${action}"
            ;;

    esac

}

###############################################################################
# Start
###############################################################################

main "$@"