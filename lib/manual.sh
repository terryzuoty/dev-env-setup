# shellcheck shell=bash
# Things only you can do. The ones that can be detected are checked, so they drop off the
# to-do list once done; the rest are printed as reminders at the end of every full run.

check_manual() {
  local email user account

  if [[ $(defaults read com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag 2>/dev/null) == 1 ]]; then
    add_item manual three-finger-drag "Three-finger drag" ok "on"
  else
    add_item manual three-finger-drag "Three-finger drag" manual "off" \
      "System Settings → Accessibility → Pointer Control → Trackpad Options…\nTurn on \"Use trackpad for dragging\" and set Dragging style to \"Three-Finger Drag\"."
  fi

  email=$(git config --file "$REPO/git/gitconfig" --get user.email)
  user=$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@github.com 2>&1 | sed -nE 's/^Hi ([^!]+)!.*/\1/p')
  if [[ -n $user ]]; then
    add_item manual github-ssh "GitHub SSH key" ok "works for $user"
  else
    add_item manual github-ssh "GitHub SSH key" manual "GitHub doesn't accept an SSH key from this Mac (or it's offline)" \
      "ssh-keygen -t ed25519 -C \"$email\"      (skip if ~/.ssh/id_ed25519 already exists)\npbcopy < ~/.ssh/id_ed25519.pub\nAdd it at https://github.com/settings/keys → New SSH key\nssh -T git@github.com      (answer yes once to trust GitHub's host key)"
  fi

  if ! command -v gh >/dev/null 2>&1; then
    add_item manual gh-login "GitHub CLI login" manual "gh isn't installed yet" "After gh is installed: gh auth login"
  elif gh auth token >/dev/null 2>&1; then
    add_item manual gh-login "GitHub CLI login" ok "logged in"
  else
    add_item manual gh-login "GitHub CLI login" manual "not logged in" "gh auth login"
  fi

  if ! command -v gcloud >/dev/null 2>&1; then
    add_item manual gcloud-login "gcloud login" manual "gcloud isn't installed yet" \
      "After gcloud-cli is installed: gcloud auth login"
  else
    account=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1)
    if [[ -n $account ]]; then
      add_item manual gcloud-login "gcloud login" ok "$account"
    else
      add_item manual gcloud-login "gcloud login" manual "not logged in" "gcloud auth login"
    fi
  fi
}

print_reminders() {
  printf '\n%sCan'\''t be checked automatically: do these once per Mac%s\n' "$C_BOLD" "$C_OFF"
  printf '  • %s\n' \
    "1Password: sign in, then Settings → Developer → Integrate with 1Password CLI (for op)" \
    "Docker Desktop: open it once and accept the terms" \
    "Rectangle Pro: enter your license, then allow it in System Settings → Privacy & Security → Accessibility" \
    "JetBrains Toolbox: install your IDEs from it" \
    "Claude, ChatGPT, Obsidian, Eudic: sign in" \
    "GitLab, if you use it: glab auth login"
}
