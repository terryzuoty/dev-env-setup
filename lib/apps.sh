# shellcheck shell=bash
# Terminal and iTerm2 profiles. An app overwrites settings changed underneath it when it quits,
# so each app must be closed first; the one running this script can't be, and is left to you.

TERMINAL_PROFILE="Clear Dark"
TERMINAL_FALLBACK="Pro"
TERMINAL_BUILTINS="/System/Applications/Utilities/Terminal.app/Contents/Resources/Initial Settings"

ITERM_PROFILE_SRC="$REPO/iterm2/profile.json"
ITERM_PROFILE_DST="$HOME/Library/Application Support/iTerm2/DynamicProfiles/dev-env-setup.json"

terminal_profile() {
  if [[ -f "$TERMINAL_BUILTINS/$TERMINAL_PROFILE.terminal" ]] ||
    defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -qF "\"$TERMINAL_PROFILE\" ="; then
    echo "$TERMINAL_PROFILE"
  else
    echo "$TERMINAL_FALLBACK"
  fi
}

terminal_fix() {
  printf '%s\n' \
    "Quit Terminal (⌘Q), open iTerm2, then run:" \
    "  cd \"$REPO\" && ./install.sh --install terminal" \
    "Or by hand, in Terminal → Settings:" \
    "  Profiles → select \"$1\" → Default" \
    "  General → On startup, open: New window with profile \"$1\""
}

check_terminal() {
  local want current_default current_startup note
  want=$(terminal_profile)
  current_default=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null)
  current_startup=$(defaults read com.apple.Terminal "Startup Window Settings" 2>/dev/null)
  note="default and new-window profile: $want"
  [[ $want != "$TERMINAL_PROFILE" ]] && note="$note ($TERMINAL_PROFILE isn't in this macOS)"

  if [[ $current_default == "$want" && $current_startup == "$want" ]]; then
    add_item terminal term "Terminal profile" ok "$note"
  elif [[ $(host_app) == Terminal ]]; then
    add_item terminal term "Terminal profile" manual \
      "should be $want; can't change it while this script runs in Terminal" "$(terminal_fix "$want")"
  elif app_running Terminal; then
    add_item terminal term "Terminal profile" todo "will set $want (asks you to quit Terminal first)" \
      "$(terminal_fix "$want")" apply_terminal "$want"
  else
    add_item terminal term "Terminal profile" todo "will set $want" "$(terminal_fix "$want")" apply_terminal "$want"
  fi
}

apply_terminal() {
  if [[ $(host_app) == Terminal ]]; then
    RESULT_REASON="this script is running in Terminal"
    return 2
  fi
  if app_running Terminal; then
    if ! confirm "Terminal is open. Quit it now so its profile can be changed?"; then
      RESULT_REASON="you chose not to quit Terminal"
      return 2
    fi
    if ! quit_app com.apple.Terminal Terminal; then
      RESULT_REASON="Terminal didn't quit (a window may be asking to confirm)"
      return 2
    fi
  fi
  defaults write com.apple.Terminal "Default Window Settings" -string "$1" &&
    defaults write com.apple.Terminal "Startup Window Settings" -string "$1" && return 0
  RESULT_REASON="defaults write failed"
  return 1
}

iterm_guid() {
  /usr/bin/python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["Profiles"][0]["Guid"])' \
    "$ITERM_PROFILE_SRC"
}

iterm_default_fix() {
  printf '%s\n' \
    "In iTerm2 → Settings → Profiles: select \"dev-env-setup\" → Other Actions… → Set as Default" \
    "Or quit iTerm2 (⌘Q) and run from Terminal:" \
    "  cd \"$REPO\" && ./install.sh --install iterm2"
}

check_iterm2() {
  local guid current fix
  fix="cd \"$REPO\" && ./install.sh --install iterm2"
  if cmp -s "$ITERM_PROFILE_SRC" "$ITERM_PROFILE_DST"; then
    add_item iterm2 iterm-profile "iTerm2 profile" ok "dev-env-setup is in iTerm2's Dynamic Profiles"
  elif [[ -f $ITERM_PROFILE_DST ]]; then
    add_item iterm2 iterm-profile "iTerm2 profile" todo "will update it from the repo" "$fix" apply_iterm_profile
  else
    add_item iterm2 iterm-profile "iTerm2 profile" todo "will add dev-env-setup to iTerm2's Dynamic Profiles" \
      "$fix" apply_iterm_profile
  fi

  guid=$(iterm_guid)
  current=$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)
  if [[ $current == "$guid" ]]; then
    add_item iterm2 iterm-default "iTerm2 default profile" ok "dev-env-setup"
  elif [[ $(host_app) == iTerm2 ]]; then
    add_item iterm2 iterm-default "iTerm2 default profile" manual \
      "should be dev-env-setup; can't change it while this script runs in iTerm2" "$(iterm_default_fix)"
  elif app_running iTerm2; then
    add_item iterm2 iterm-default "iTerm2 default profile" todo \
      "will set dev-env-setup (asks you to quit iTerm2 first)" "$(iterm_default_fix)" apply_iterm_default "$guid"
  else
    add_item iterm2 iterm-default "iTerm2 default profile" todo "will set dev-env-setup" \
      "$(iterm_default_fix)" apply_iterm_default "$guid"
  fi
}

apply_iterm_profile() {
  mkdir -p "$(dirname "$ITERM_PROFILE_DST")" && cp "$ITERM_PROFILE_SRC" "$ITERM_PROFILE_DST" && return 0
  RESULT_REASON="couldn't copy the profile into $ITERM_PROFILE_DST"
  return 1
}

apply_iterm_default() {
  if [[ $(host_app) == iTerm2 ]]; then
    RESULT_REASON="this script is running in iTerm2"
    return 2
  fi
  if app_running iTerm2; then
    if ! confirm "iTerm2 is open. Quit it now so its default profile can be changed?"; then
      RESULT_REASON="you chose not to quit iTerm2"
      return 2
    fi
    if ! quit_app com.googlecode.iterm2 iTerm2; then
      RESULT_REASON="iTerm2 didn't quit (a window may be asking to confirm)"
      return 2
    fi
  fi
  defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$1" && return 0
  RESULT_REASON="defaults write failed"
  return 1
}
