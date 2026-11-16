#!/bin/bash
# Checks this Mac against the setup in this repo. With --install it applies what's missing.

# Sourcing it would close your shell at the first exit.
case "${ZSH_EVAL_CONTEXT:-}" in
  *:file*) echo "Run it as ./install.sh, not with source." >&2; return 2 ;;
esac
if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then
  echo "Run it as ./install.sh, not with source." >&2
  return 2
fi
# Started as `zsh install.sh` or `sh install.sh`: run it again under bash, which every macOS ships.
if [ -z "${BASH_VERSION:-}" ] || (shopt -oq posix) 2>/dev/null; then
  exec /bin/bash "$0" "$@"
fi

set -o pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
BREWFILE="$REPO/Brewfile"
ALL_STEPS=(brew gcloud dotfiles terminal iterm2 manual)

# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"
# shellcheck source=lib/brew.sh
source "$REPO/lib/brew.sh"
# shellcheck source=lib/gcloud.sh
source "$REPO/lib/gcloud.sh"
# shellcheck source=lib/dotfiles.sh
source "$REPO/lib/dotfiles.sh"
# shellcheck source=lib/apps.sh
source "$REPO/lib/apps.sh"
# shellcheck source=lib/manual.sh
source "$REPO/lib/manual.sh"

usage() {
  cat <<EOF
Usage: ./install.sh [--install] [step ...]

  (no flag)   Check this Mac and report. Changes nothing.
  --install   Check, report, ask y/n, then apply what's missing and check again.

Steps (default: all): ${ALL_STEPS[*]}

Exit code: 0 when everything is in place, 1 when something isn't, 2 when a prerequisite is missing.
EOF
}

MODE=check
STEPS=()
for arg in "$@"; do
  case $arg in
    --install) MODE=install ;;
    -h | --help) usage; exit 0 ;;
    brew | gcloud | dotfiles | terminal | iterm2 | manual) STEPS+=("$arg") ;;
    *) printf 'Unknown argument: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done
[[ ${#STEPS[@]} -eq 0 ]] && STEPS=("${ALL_STEPS[@]}")

wants_step() {
  local s
  for s in "${STEPS[@]}"; do [[ $s == "$1" ]] && return 0; done
  return 1
}

preflight() {
  local missing=0
  if [[ $(uname -m) != arm64 ]]; then
    printf '%s✗%s This setup is for Apple silicon Macs only (this one is %s).\n' "$C_FAIL" "$C_OFF" "$(uname -m)"
    return 1
  fi
  printf 'macOS %s on Apple silicon\n' "$(sw_vers -productVersion)"
  if ! xcode-select -p >/dev/null 2>&1; then
    printf '\n%s✗%s Apple command line tools are not installed. Install them, then run this script again:\n' \
      "$C_FAIL" "$C_OFF"
    printf '    xcode-select --install\n'
    missing=1
  fi
  if [[ ! -x /opt/homebrew/bin/brew ]]; then
    printf '\n%s✗%s Homebrew is not installed. Install it, then run this script again:\n' "$C_FAIL" "$C_OFF"
    # shellcheck disable=SC2016
    printf '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n'
    missing=1
  fi
  [[ $missing -eq 0 ]] || return 1
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export HOMEBREW_NO_ENV_HINTS=1
  [[ $MODE == check ]] && export HOMEBREW_NO_AUTO_UPDATE=1
  return 0
}

run_checks() {
  reset_items
  wants_step brew && check_brew
  wants_step gcloud && check_gcloud
  wants_step dotfiles && check_dotfiles
  wants_step terminal && check_terminal
  wants_step iterm2 && check_iterm2
  wants_step manual && check_manual
}

run_apply() {
  local i=$1 rc
  RESULT_REASON='' RESULT_FIX=''
  printf '\n%s→ %s%s\n' "$C_BOLD" "${ITEM_LABEL[i]}" "$C_OFF"
  "${ITEM_APPLY[i]}" "${ITEM_ARG[i]}"
  rc=$?
  hash -r
  case $rc in
    0) record_apply "${ITEM_ID[i]}" "done" '' '' ;;
    2)
      printf '  %sskipped:%s %s\n' "$C_MANUAL" "$C_OFF" "$RESULT_REASON"
      record_apply "${ITEM_ID[i]}" skipped "skipped: $RESULT_REASON" "$RESULT_FIX"
      ;;
    *)
      printf '  %sfailed:%s %s\n' "$C_FAIL" "$C_OFF" "${RESULT_REASON:-failed}"
      record_apply "${ITEM_ID[i]}" failed "failed: ${RESULT_REASON:-see the output above}" "$RESULT_FIX"
      ;;
  esac
}

apply_all() {
  local i admin_labels=''
  for i in "${!ITEM_ID[@]}"; do
    [[ ${ITEM_STATE[i]} == todo && ${ITEM_ADMIN[i]} == 1 ]] && admin_labels="$admin_labels ${ITEM_LABEL[i]}"
  done
  # Items that need the Mac password go first, so it is asked for once.
  for i in "${!ITEM_ID[@]}"; do
    [[ ${ITEM_STATE[i]} == todo && ${ITEM_ADMIN[i]} == 1 ]] || continue
    if ensure_sudo "These need your Mac password to install:$admin_labels"; then
      run_apply "$i"
    else
      record_apply "${ITEM_ID[i]}" skipped "skipped: the Mac password wasn't entered" ''
    fi
  done
  for i in "${!ITEM_ID[@]}"; do
    [[ ${ITEM_STATE[i]} == todo && ${ITEM_ADMIN[i]} != 1 ]] && run_apply "$i"
  done
}

finish() {
  local output log_dir log_file
  output=$(
    print_report problems
    print_summary
    print_todo
    wants_step manual && print_reminders
  )
  printf '%s\n' "$output"
  if [[ $MODE == install ]]; then
    log_dir="$HOME/Library/Logs/dev-env-setup"
    log_file="$log_dir/install-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$log_dir" && printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g' >"$log_file" &&
      printf '\nSaved this summary to %s\n' "$log_file"
  fi
  [[ $(not_ok_count) -eq 0 ]]
}

main() {
  printf '%sdev-env-setup%s: %s\n' "$C_BOLD" "$C_OFF" "$REPO"
  preflight || exit 2

  if [[ $MODE == check ]]; then
    printf 'Checking only; nothing will be changed. Run with --install to apply.\n'
  fi
  printf '%s✓ in place  + the script will do it  ! needs you  ✗ problem%s\n' "$C_DIM" "$C_OFF"
  run_checks
  print_report all

  if [[ $MODE == check ]]; then
    output=$(print_summary; print_todo; wants_step manual && print_reminders)
    printf '%s\n' "$output"
    [[ $(not_ok_count) -eq 0 ]] && exit 0
    exit 1
  fi

  print_summary
  if [[ $(count_state todo) -eq 0 ]]; then
    printf '\nNothing for the script to change.\n'
    print_todo
    wants_step manual && print_reminders
    [[ $(not_ok_count) -eq 0 ]] && exit 0
    exit 1
  fi
  printf '\n'
  if ! confirm "Apply the $(count_state todo) items marked +?"; then
    printf 'Stopped. Nothing was changed.\n'
    exit 1
  fi

  apply_all
  printf '\n%sChecking again…%s\n' "$C_BOLD" "$C_OFF"
  run_checks
  finish && exit 0
  exit 1
}

main
