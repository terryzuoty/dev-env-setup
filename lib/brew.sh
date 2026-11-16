# shellcheck shell=bash
# Homebrew formulae and casks listed in the Brewfile.

brewfile_names() {
  sed -nE 's/^[[:space:]]*'"$1"'[[:space:]]+"([^"]+)".*/\1/p' "$BREWFILE"
}

# brew_rows formula|cask NAMES... -> one tab-separated row per name (see lib/brew_info.py)
brew_rows() {
  local kind=$1 json name
  shift
  [[ $# -eq 0 ]] && return 0
  if json=$(brew info --json=v2 "--$kind" "$@" 2>/dev/null); then
    printf '%s' "$json" | /usr/bin/python3 -I "$REPO/lib/brew_info.py" "$kind" "$@"
    return
  fi
  # brew rejects the whole batch if one name is unknown, so look them up one by one.
  for name in "$@"; do
    if json=$(brew info --json=v2 "--$kind" "$name" 2>/dev/null); then
      printf '%s' "$json" | /usr/bin/python3 -I "$REPO/lib/brew_info.py" "$kind" "$name"
    else
      printf '%s\tmissing\t-\t0\t0\t0\t-\t-\t-\n' "$name"
    fi
  done
}

# found_outside apps bins fonts -> 0 if the cask's app, command or font is already on this Mac
found_outside() {
  local IFS='|' x
  if [[ $1 != - ]]; then
    for x in $1; do
      [[ -d "/Applications/$x" || -d "$HOME/Applications/$x" ]] && return 0
    done
    return 1
  fi
  if [[ $2 != - ]]; then
    for x in $2; do command -v "$x" >/dev/null 2>&1 && return 0; done
    return 1
  fi
  if [[ $3 != - ]]; then
    for x in $3; do
      [[ -f "/Library/Fonts/$x" || -f "$HOME/Library/Fonts/$x" ]] && return 0
    done
  fi
  return 1
}

check_brew() {
  local names=() name found canon installed onreq admin apps bins fonts note
  while IFS= read -r name; do names+=("$name"); done < <(brewfile_names brew)
  while IFS=$'\t' read -r name found canon installed onreq admin apps bins fonts; do
    if [[ $found != found ]]; then
      add_item brew-formula "f:$name" "$name" fail "unknown formula (renamed or removed?)" \
        "Look it up with: brew search $name\nThen fix its line in $BREWFILE"
    elif [[ $installed == 1 && $onreq == 1 ]]; then
      add_item brew-formula "f:$name" "$name" ok "installed"
    elif [[ $installed == 1 ]]; then
      note="installed only as a dependency; will mark it as wanted so brew autoremove keeps it"
      add_item brew-formula "f:$name" "$name" todo "$note" \
        "brew tab --installed-on-request $canon" apply_brew_mark "$canon"
    else
      add_item brew-formula "f:$name" "$name" todo "will install" "brew install $name" apply_brew_formula "$name"
    fi
  done < <(brew_rows formula ${names[@]+"${names[@]}"})

  names=()
  while IFS= read -r name; do names+=("$name"); done < <(brewfile_names cask)
  while IFS=$'\t' read -r name found canon installed onreq admin apps bins fonts; do
    if [[ $found != found ]]; then
      add_item brew-cask "c:$name" "$name" fail "unknown cask (renamed or removed?)" \
        "Look it up with: brew search --cask $name\nThen fix its line in $BREWFILE"
    elif [[ $installed == 1 ]]; then
      add_item brew-cask "c:$name" "$name" ok "installed"
    elif found_outside "$apps" "$bins" "$fonts"; then
      add_item brew-cask "c:$name" "$name" ok "installed outside Homebrew"
    elif [[ $admin == 1 ]]; then
      add_item brew-cask "c:$name" "$name" todo "will install (asks for your Mac password)" \
        "brew install --cask $name   (asks for your Mac password)" apply_brew_cask "$name" 1
    else
      add_item brew-cask "c:$name" "$name" todo "will install" "brew install --cask $name" apply_brew_cask "$name"
    fi
  done < <(brew_rows cask ${names[@]+"${names[@]}"})
}

apply_brew_formula() {
  brew install --formula "$1" && return 0
  RESULT_REASON="brew install failed (see the output above)"
  return 1
}

apply_brew_mark() {
  brew tab --installed-on-request "$1" && return 0
  RESULT_REASON="brew tab failed (see the output above)"
  return 1
}

apply_brew_cask() {
  brew install --cask "$1" && return 0
  RESULT_REASON="brew install failed (see the output above)"
  return 1
}
