# shellcheck shell=bash
# Extra gcloud components. Homebrew has no package for these; gcloud installs them itself.

GCLOUD_COMPONENTS=(gke-gcloud-auth-plugin)

gcloud_sdk_bin() {
  local g
  if [[ -d /opt/homebrew/share/google-cloud-sdk/bin ]]; then
    echo /opt/homebrew/share/google-cloud-sdk/bin
    return 0
  fi
  g=$(command -v gcloud 2>/dev/null) || return 1
  dirname "$(/usr/bin/python3 -I -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$g")"
}

check_gcloud() {
  local c bin
  bin=$(gcloud_sdk_bin)
  for c in "${GCLOUD_COMPONENTS[@]}"; do
    if [[ -n $bin && -x "$bin/$c" ]]; then
      add_item gcloud "g:$c" "$c" ok "installed"
    elif [[ -n $bin || $(item_state c:gcloud-cli) == todo ]]; then
      add_item gcloud "g:$c" "$c" todo "will install with gcloud" \
        "gcloud components install $c" apply_gcloud_component "$c"
    else
      add_item gcloud "g:$c" "$c" manual "needs gcloud-cli, which isn't installed" \
        "brew install --cask gcloud-cli\ngcloud components install $c"
    fi
  done
}

apply_gcloud_component() {
  hash -r
  if ! command -v gcloud >/dev/null 2>&1; then
    RESULT_REASON="gcloud isn't installed"
    RESULT_FIX="brew install --cask gcloud-cli\ngcloud components install $1"
    return 2
  fi
  gcloud components install "$1" --quiet && return 0
  RESULT_REASON="gcloud components install failed (see the output above)"
  return 1
}
