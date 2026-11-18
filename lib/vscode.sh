# shellcheck shell=bash
# VS Code extensions listed in vscode/extensions.txt, installed with VS Code's own `code` command.
# They install fine while VS Code is open; it picks them up after a reload.

VSCODE_EXTENSIONS="$REPO/vscode/extensions.txt"
CODE_BIN=/opt/homebrew/bin/code

# Extension IDs from the list, without comments or blank lines.
vscode_wanted() {
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$VSCODE_EXTENSIONS" | grep -v '^$'
}

check_vscode() {
  local installed id lower
  if [[ ! -x $CODE_BIN ]]; then
    if [[ $(item_state c:visual-studio-code) == todo ]]; then
      while IFS= read -r id; do
        add_item vscode "v:$id" "$id" todo "will install once VS Code is installed" \
          "code --install-extension $id" apply_vscode_extension "$id"
      done < <(vscode_wanted)
    else
      add_item vscode v:code "VS Code" manual "isn't installed, so its extensions can't be" \
        "cd \"$REPO\" && ./install.sh --install brew vscode"
    fi
    return
  fi

  # IDs are case-insensitive; `code --list-extensions` prints them as each publisher wrote them.
  installed=$("$CODE_BIN" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
  while IFS= read -r id; do
    lower=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')
    if grep -qxF "$lower" <<<"$installed"; then
      add_item vscode "v:$id" "$id" ok "installed"
    else
      add_item vscode "v:$id" "$id" todo "will install" "code --install-extension $id" apply_vscode_extension "$id"
    fi
  done < <(vscode_wanted)
}

apply_vscode_extension() {
  if [[ ! -x $CODE_BIN ]]; then
    RESULT_REASON="VS Code isn't installed"
    RESULT_FIX="brew install --cask visual-studio-code\ncode --install-extension $1"
    return 2
  fi
  "$CODE_BIN" --install-extension "$1" && return 0
  RESULT_REASON="code --install-extension failed (see the output above); is the ID right?"
  return 1
}
