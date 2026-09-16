#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2026-present Poing Studios
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ANSI Colors & Text Attributes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Logging & UI Helpers
log_info() {
    echo -e "  ${DIM}•${NC} $*"
}

log_success() {
    echo -e "  ${GREEN}✓${NC} $*"
}

log_warn() {
    echo -e "  ${YELLOW}⚠ Warning:${NC} $*"
}

log_error() {
    echo -e "  ${RED}✖ Error:${NC} $*" >&2
}

# Branding Banners
print_welcome_banner() {
    echo -e "\n  ${BOLD}${CYAN}Godot Swift Plugin${NC} ${DIM}• Build native Apple plugins for Godot with pure Swift${NC}\n"
}

print_finish_banner() {
    echo -e "\n  ${BOLD}🎉 Happy Game Dev!${NC}"
    echo -e "  ⭐ Star on GitHub:     ${CYAN}https://github.com/poingstudios/godot-swift-plugin${NC}"
    echo -e "  💖 Support on Patreon: ${CYAN}https://www.patreon.com/c/poingstudios${NC}\n"
}

# Single Step Runner with live progress bar and timers
# Supports: run_step [est_secs] <step_label> <success_label> <cmd...>
run_step() {
    local est_secs=15
    local step_label=""
    local success_label=""

    if [[ "$1" =~ ^[0-9]+$ ]]; then
        est_secs="$1"
        step_label="$2"
        success_label="$3"
        shift 3
    else
        step_label="$1"
        success_label="$2"
        shift 2
    fi

    local step_idx="${CURRENT_STEP_INDEX:-1}"
    local total_steps="${CURRENT_STEP_TOTAL:-1}"

    local base_pct=$(( (step_idx - 1) * 100 / total_steps ))
    local target_pct=$(( step_idx * 100 / total_steps ))
    local span=$(( target_pct - base_pct ))
    [ "${span}" -lt 1 ] && span=1

    local is_tty=false
    if [ -t 2 ] || [ -t 1 ]; then
        is_tty=true
    fi

    local log_file
    log_file="$(mktemp /tmp/gsp_step_XXXXXX)"

    local spinner_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local delay=0.1
    if [ "${is_tty}" = false ]; then
        delay=0.3
    fi
    local bar_width=10
    local start_time
    start_time="$(date +%s)"

    "$@" > "${log_file}" 2>&1 &
    local pid=$!

    if [ "${is_tty}" = true ]; then
        printf "\033[?25l" >&2
        local tick=0
        while kill -0 "${pid}" 2>/dev/null; do
            local spin="${spinner_chars[tick % ${#spinner_chars[@]}]}"
            local elapsed=$(( $(date +%s) - start_time ))
            local elapsed_ms=$(( tick * 100 ))
            local inc=$(( elapsed_ms * span / (est_secs * 1000) ))
            [ "${inc}" -ge "${span}" ] && inc=$(( span - 1 ))
            local pct=$(( base_pct + inc ))
            [ "${pct}" -lt 1 ] && pct=1

            local filled_cnt=$(( pct * bar_width / 100 ))
            local empty_cnt=$(( bar_width - filled_cnt ))
            local filled=""
            local empty=""
            [ "${filled_cnt}" -gt 0 ] && filled=$(printf "%*s" "${filled_cnt}" | tr " " "█")
            [ "${empty_cnt}" -gt 0 ] && empty=$(printf "%*s" "${empty_cnt}" | tr " " "░")

            printf "\r\033[K  \033[1;36m%s\033[0m \033[2m[\033[0m\033[36m%s\033[0m\033[2m%s]\033[0m \033[1m%3d%%\033[0m  %s \033[2m(%ds)\033[0m" \
                "${spin}" "${filled}" "${empty}" "${pct}" "${step_label}" "${elapsed}" >&2

            tick=$(( tick + 1 ))
            sleep 0.1
        done
        printf "\033[?25h" >&2
    else
        local tick=0
        local last_logged_sec=-1
        while kill -0 "${pid}" 2>/dev/null; do
            local elapsed=$(( $(date +%s) - start_time ))
            if [ "${elapsed}" -ne "${last_logged_sec}" ] && { [ "${elapsed}" -eq 0 ] || [ $(( elapsed % 3 )) -eq 0 ]; }; then
                last_logged_sec="${elapsed}"
                local spin="${spinner_chars[tick % ${#spinner_chars[@]}]}"
                local elapsed_ms=$(( elapsed * 1000 ))
                local inc=$(( elapsed_ms * span / (est_secs * 1000) ))
                [ "${inc}" -ge "${span}" ] && inc=$(( span - 1 ))
                local pct=$(( base_pct + inc ))
                [ "${pct}" -lt 1 ] && pct=1

                local filled_cnt=$(( pct * bar_width / 100 ))
                local empty_cnt=$(( bar_width - filled_cnt ))
                local filled=""
                local empty=""
                [ "${filled_cnt}" -gt 0 ] && filled=$(printf "%*s" "${filled_cnt}" | tr " " "█")
                [ "${empty_cnt}" -gt 0 ] && empty=$(printf "%*s" "${empty_cnt}" | tr " " "░")

                printf "  \033[1;36m%s\033[0m \033[2m[\033[0m\033[36m%s\033[0m\033[2m%s]\033[0m \033[1m%3d%%\033[0m  %s \033[2m(%ds)\033[0m\n" \
                    "${spin}" "${filled}" "${empty}" "${pct}" "${step_label}" "${elapsed}" >&2
            fi
            tick=$(( tick + 1 ))
            sleep 0.5
        done
    fi

    local exit_code=0
    wait "${pid}" || exit_code=$?
    local total_elapsed=$(( $(date +%s) - start_time ))

    local done_pct="${target_pct}"
    local done_filled_cnt=$(( done_pct * bar_width / 100 ))
    local done_empty_cnt=$(( bar_width - done_filled_cnt ))
    local done_filled=""
    local done_empty=""
    [ "${done_filled_cnt}" -gt 0 ] && done_filled=$(printf "%*s" "${done_filled_cnt}" | tr " " "█")
    [ "${done_empty_cnt}" -gt 0 ] && done_empty=$(printf "%*s" "${done_empty_cnt}" | tr " " "░")
    local bar_done
    bar_done="$(printf "\033[2m[\033[0m\033[32m%s\033[0m\033[2m%s]\033[0m \033[1;32m%3d%%\033[0m" "${done_filled}" "${done_empty}" "${done_pct}")"

    local prefix_clear=""
    [ "${is_tty}" = true ] && prefix_clear="\r\033[K"

    local warnings=()
    if [ -f "${log_file}" ]; then
        while IFS= read -r wline; do
            [ -n "${wline}" ] && warnings+=("${wline}")
        done < <(grep -E "(warning:|⚠️)" "${log_file}" 2>/dev/null | grep -v "no_warning_for_no_symbols" | head -n 5 || true)
    fi

    if [ "${exit_code}" -eq 0 ]; then
        if [ ${#warnings[@]} -gt 0 ]; then
            printf "%b  \033[1;33m⚠\033[0m %b  %s \033[2m(%d warning%s)\033[0m \033[2m(%ds)\033[0m\n" \
                "${prefix_clear}" "${bar_done}" "${success_label}" "${#warnings[@]}" "$([ ${#warnings[@]} -gt 1 ] && echo "s" || echo "")" "${total_elapsed}" >&2
            for w in "${warnings[@]}"; do
                printf "    \033[33m%s\033[0m\n" "${w}" >&2
            done
        else
            printf "%b  \033[1;32m✓\033[0m %b  %s \033[2m(%ds)\033[0m\n" "${prefix_clear}" "${bar_done}" "${success_label}" "${total_elapsed}" >&2
        fi
        rm -f "${log_file}"
        return 0
    else
        local fail_pct=$(( base_pct + (tick * 100 * span / (est_secs * 1000)) ))
        [ "${fail_pct}" -gt "${target_pct}" ] && fail_pct="${target_pct}"
        [ "${fail_pct}" -lt 1 ] && fail_pct=1
        local fail_filled_cnt=$(( fail_pct * bar_width / 100 ))
        local fail_empty_cnt=$(( bar_width - fail_filled_cnt ))
        local fail_filled=""
        local fail_empty=""
        [ "${fail_filled_cnt}" -gt 0 ] && fail_filled=$(printf "%*s" "${fail_filled_cnt}" | tr " " "█")
        [ "${fail_empty_cnt}" -gt 0 ] && fail_empty=$(printf "%*s" "${fail_empty_cnt}" | tr " " "░")
        local bar_fail
        bar_fail="$(printf "\033[2m[\033[0m\033[31m%s\033[0m\033[2m%s]\033[0m \033[1;31m%3d%%\033[0m" "${fail_filled}" "${fail_empty}" "${fail_pct}")"

        printf "%b  \033[1;31m✖\033[0m %b  %s \033[1;31m(failed after %ds)\033[0m\n\n" "${prefix_clear}" "${bar_fail}" "${step_label}" "${total_elapsed}" >&2
        if [ -f "${log_file}" ]; then
            cat "${log_file}" >&2
            rm -f "${log_file}"
        fi
        return "${exit_code}"
    fi
}


# Dynamic Step Pipeline (SOLID / DRY)
PIPELINE_TAGS=()
PIPELINE_ESTS=()
PIPELINE_LABELS=()
PIPELINE_SUCCESS_LABELS=()
PIPELINE_HANDLERS=()

pipeline_reset() {
    PIPELINE_TAGS=()
    PIPELINE_ESTS=()
    PIPELINE_LABELS=()
    PIPELINE_SUCCESS_LABELS=()
    PIPELINE_HANDLERS=()
}

pipeline_add_step() {
    local tag="$1"
    local est_secs="$2"
    local label="$3"
    local success_label="$4"
    local handler="$5"

    PIPELINE_TAGS+=("${tag}")
    PIPELINE_ESTS+=("${est_secs}")
    PIPELINE_LABELS+=("${label}")
    PIPELINE_SUCCESS_LABELS+=("${success_label}")
    PIPELINE_HANDLERS+=("${handler}")
}

pipeline_count() {
    echo "${#PIPELINE_TAGS[@]}"
}

pipeline_run() {
    local total="${#PIPELINE_TAGS[@]}"
    if [ "${total}" -eq 0 ]; then
        return 0
    fi

    local i=0
    for (( i=0; i<total; i++ )); do
        local step_idx=$(( i + 1 ))
        local tag="${PIPELINE_TAGS[i]}"
        local est="${PIPELINE_ESTS[i]}"
        local label="${PIPELINE_LABELS[i]}"
        local succ="${PIPELINE_SUCCESS_LABELS[i]}"
        local handler="${PIPELINE_HANDLERS[i]}"

        local prefix=""
        if [ -n "${tag}" ]; then
            prefix="[${tag} ${step_idx}/${total}]"
        else
            prefix="[${step_idx}/${total}]"
        fi

        CURRENT_STEP_INDEX="${step_idx}" CURRENT_STEP_TOTAL="${total}" \
            run_step "${est}" "${prefix} ${label}" "${prefix} ${succ}" "${handler}"
    done
}
