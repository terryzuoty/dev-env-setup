# shellcheck shell=bash
# Item registry, report output, prompts and app helpers shared by every step.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_OK=$'\033[32m' C_TODO=$'\033[33m' C_MANUAL=$'\033[35m' C_FAIL=$'\033[31m'
  C_DIM=$'\033[2m' C_BOLD=$'\033[1m' C_OFF=$'\033[0m'
else
  C_OK='' C_TODO='' C_MANUAL='' C_FAIL='' C_DIM='' C_BOLD='' C_OFF=''
fi

# One entry per requirement. State: ok | todo (script does it) | manual (needs you) | fail.
reset_items() {
  ITEM_ID=() ITEM_STEP=() ITEM_LABEL=() ITEM_STATE=() ITEM_NOTE=() ITEM_FIX=()
  ITEM_APPLY=() ITEM_ARG=() ITEM_ADMIN=()
}

# add_item step id label state note [fix] [apply_function] [apply_arg] [needs_admin]
add_item() {
  ITEM_STEP+=("$1") ITEM_ID+=("$2") ITEM_LABEL+=("$3") ITEM_STATE+=("$4") ITEM_NOTE+=("$5")
  ITEM_FIX+=("${6:-}") ITEM_APPLY+=("${7:-}") ITEM_ARG+=("${8:-}") ITEM_ADMIN+=("${9:-0}")
}

item_state() {
  local i
  for i in "${!ITEM_ID[@]}"; do
    [[ ${ITEM_ID[i]} == "$1" ]] && { printf '%s' "${ITEM_STATE[i]}"; return 0; }
  done
  return 1
}

count_state() {
  local i n=0
  for i in "${!ITEM_ID[@]}"; do [[ ${ITEM_STATE[i]} == "$1" ]] && n=$((n + 1)); done
  printf '%s' "$n"
}

not_ok_count() {
  printf '%s' $(($(count_state todo) + $(count_state manual) + $(count_state fail)))
}

step_title() {
  case $1 in
    brew-formula) echo "Homebrew formulae" ;;
    brew-cask) echo "Homebrew casks" ;;
    gcloud) echo "gcloud components" ;;
    rust) echo "Rust toolchain" ;;
    node) echo "Node.js" ;;
    languages) echo "Languages: run a small program in each" ;;
    dotfiles) echo "Shell and git config" ;;
    terminal) echo "Terminal" ;;
    iterm2) echo "iTerm2" ;;
    manual) echo "Manual settings and logins" ;;
    *) echo "$1" ;;
  esac
}

state_mark() {
  case $1 in
    ok) printf '%s✓%s' "$C_OK" "$C_OFF" ;;
    todo) printf '%s+%s' "$C_TODO" "$C_OFF" ;;
    manual) printf '%s!%s' "$C_MANUAL" "$C_OFF" ;;
    *) printf '%s✗%s' "$C_FAIL" "$C_OFF" ;;
  esac
}

# print_report all|problems
print_report() {
  local i step=''
  for i in "${!ITEM_ID[@]}"; do
    [[ $1 == problems && ${ITEM_STATE[i]} == ok ]] && continue
    if [[ ${ITEM_STEP[i]} != "$step" ]]; then
      step=${ITEM_STEP[i]}
      printf '\n%s%s%s\n' "$C_BOLD" "$(step_title "$step")" "$C_OFF"
    fi
    printf '  %s %-24s %s\n' "$(state_mark "${ITEM_STATE[i]}")" "${ITEM_LABEL[i]}" "${ITEM_NOTE[i]}"
  done
}

print_summary() {
  printf '\n%s✓ %s in place   %s+ %s for the script   %s! %s need you   %s✗ %s problems%s\n' \
    "$C_OK" "$(count_state ok)" "$C_TODO" "$(count_state todo)" \
    "$C_MANUAL" "$(count_state manual)" "$C_FAIL" "$(count_state fail)" "$C_OFF"
}

# Results recorded while applying, so the to-do list can say why something was skipped.
AP_ID=() AP_STATUS=() AP_REASON=() AP_FIX=()

record_apply() {
  AP_ID+=("$1") AP_STATUS+=("$2") AP_REASON+=("$3") AP_FIX+=("$4")
}

apply_record() {
  local i field=$2
  for i in "${!AP_ID[@]}"; do
    if [[ ${AP_ID[i]} == "$1" ]]; then
      case $field in
        status) printf '%s' "${AP_STATUS[i]}" ;;
        reason) printf '%s' "${AP_REASON[i]}" ;;
        fix) printf '%s' "${AP_FIX[i]}" ;;
      esac
      return 0
    fi
  done
  return 1
}

indent() { sed 's/^/       /'; }

print_todo() {
  local i n=0 pending=0 reason fix
  for i in "${!ITEM_ID[@]}"; do
    [[ ${ITEM_STATE[i]} == todo ]] && ! apply_record "${ITEM_ID[i]}" status >/dev/null && pending=$((pending + 1))
  done

  printf '\n%sTo do%s\n' "$C_BOLD" "$C_OFF"
  if [[ $pending -gt 0 ]]; then
    n=$((n + 1))
    printf '  %s. Apply the %s items marked + :\n' "$n" "$pending"
    printf '%s\n' "cd \"$REPO\" && ./install.sh --install" | indent
  fi
  for i in "${!ITEM_ID[@]}"; do
    case ${ITEM_STATE[i]} in
      ok) continue ;;
      todo) apply_record "${ITEM_ID[i]}" status >/dev/null || continue ;;
    esac
    reason=$(apply_record "${ITEM_ID[i]}" reason)
    [[ -z $reason ]] && reason=${ITEM_NOTE[i]}
    fix=$(apply_record "${ITEM_ID[i]}" fix)
    [[ -z $fix ]] && fix=${ITEM_FIX[i]}
    n=$((n + 1))
    printf '  %s. %s: %s\n' "$n" "${ITEM_LABEL[i]}" "$reason"
    [[ -n $fix ]] && printf '%b\n' "$fix" | indent
  done
  [[ $n -eq 0 ]] && printf '  Nothing. This Mac matches the setup.\n'
}

# ask "question" -> REPLY_ANSWER (empty on end of input)
ask() {
  printf '%s ' "$1"
  REPLY_ANSWER=''
  IFS= read -r REPLY_ANSWER || REPLY_ANSWER=''
}

confirm() {
  ask "$1 [y/N]"
  case $REPLY_ANSWER in y | Y | yes | Yes | YES) return 0 ;; *) return 1 ;; esac
}

# Which app this script is running in: Terminal, iTerm2 or other.
host_app() {
  case "${__CFBundleIdentifier:-}" in
    com.apple.Terminal) echo Terminal; return ;;
    com.googlecode.iterm2) echo iTerm2; return ;;
  esac
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal) echo Terminal ;;
    iTerm.app) echo iTerm2 ;;
    *) echo other ;;
  esac
}

app_running() { pgrep -xq "$1"; }

# quit_app bundle_id process_name
quit_app() {
  local n=0
  osascript -e "tell application id \"$1\" to quit" >/dev/null 2>&1
  while app_running "$2" && [[ $n -lt 30 ]]; do
    sleep 0.5
    n=$((n + 1))
  done
  ! app_running "$2"
}

SUDO_STATE=''
# ensure_sudo "why" -> asks for the Mac password at most once per run
ensure_sudo() {
  [[ $SUDO_STATE == ok ]] && return 0
  [[ $SUDO_STATE == no ]] && return 1
  if sudo -n true 2>/dev/null; then
    SUDO_STATE=ok
    return 0
  fi
  printf '\n%s\n' "$1"
  if sudo -v; then SUDO_STATE=ok; else SUDO_STATE=no; fi
  [[ $SUDO_STATE == ok ]]
}
