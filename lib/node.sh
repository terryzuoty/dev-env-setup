# shellcheck shell=bash
# Node.js from fnm. Homebrew installs fnm but no Node; fnm downloads Node versions itself.
# Projects pick their own version with .nvmrc or .node-version; the default is used everywhere else.

FNM=/opt/homebrew/bin/fnm

# The default Node version (e.g. v24.11.1), or nothing when fnm has none yet.
node_default() {
  "$FNM" default 2>/dev/null
}

# Homebrew's node, installed by hand and needed by no other formula: a second node next to fnm's.
brew_node_left_over() {
  brew leaves --installed-on-request 2>/dev/null | grep -qx node
}

check_node() {
  local current fix
  fix="$FNM install --lts"
  if [[ -x $FNM ]]; then
    current=$(node_default)
    if [[ -n $current ]]; then
      add_item node node-default "Node default" ok "fnm default: $current"
    else
      add_item node node-default "Node default" todo "will install the latest LTS with fnm and make it the default" \
        "$fix" apply_node_default
    fi
  elif [[ $(item_state f:fnm) == todo ]]; then
    add_item node node-default "Node default" todo "will install the latest LTS once fnm is installed" \
      "brew install fnm\n$fix" apply_node_default
  else
    add_item node node-default "Node default" manual "needs fnm, which isn't installed" "brew install fnm\n$fix"
  fi

  if brew_node_left_over; then
    add_item node brew-node "Homebrew node" manual \
      "no longer in the Brewfile; it would be a second node next to fnm's" \
      "brew uninstall node\nGlobal npm tools you need: reinstall them with fnm's Node (npm install -g <tool>)"
  fi
}

apply_node_default() {
  if [[ ! -x $FNM ]]; then
    RESULT_REASON="fnm isn't installed"
    RESULT_FIX="brew install fnm\n$FNM install --lts"
    return 2
  fi
  # The first Node fnm installs becomes the default. If the LTS was already there without a
  # default, point the default at it.
  "$FNM" install --lts
  [[ -n $(node_default) ]] && return 0
  "$FNM" default lts-latest && [[ -n $(node_default) ]] && return 0
  RESULT_REASON="fnm didn't set a default Node (see the output above)"
  RESULT_FIX="$FNM install --lts\n$FNM default lts-latest"
  return 1
}
