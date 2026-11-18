# shellcheck shell=bash disable=SC2088
# ~/.zprofile, ~/.zshrc and ~/.gitconfig stay normal files that load the repo's version first.
# They are not symlinks because apps like Docker Desktop append their own lines to them;
# anything below the block belongs to this Mac and overrides the repo.

BLOCK_BEGIN="# >>> dev-env-setup >>>"
BLOCK_END="# <<< dev-env-setup <<<"

# The folders zsh/zshrc adds to fpath. Keep this in step with the fpath line there.
ZSH_COMPLETION_DIRS=(/opt/homebrew/share/zsh-completions /opt/homebrew/share/zsh/site-functions "$HOME/.docker/completions")

dot_file() {
  case $1 in
    zprofile) echo "$HOME/.zprofile" ;;
    zshrc) echo "$HOME/.zshrc" ;;
    gitconfig) echo "$HOME/.gitconfig" ;;
  esac
}

dot_block() {
  local src
  case $1 in
    zprofile | zshrc)
      src="$REPO/zsh/$1"
      printf '%s\n[[ -f "%s" ]] && source "%s"\n%s\n' "$BLOCK_BEGIN" "$src" "$src" "$BLOCK_END"
      ;;
    gitconfig)
      printf '%s\n[include]\n\tpath = "%s"\n%s\n' "$BLOCK_BEGIN" "$REPO/git/gitconfig" "$BLOCK_END"
      ;;
  esac
}

# dot_state kind -> ok | new | existing | stale
dot_state() {
  local file want lines
  file=$(dot_file "$1")
  want=$(dot_block "$1")
  if [[ ! -e $file ]]; then
    echo new
    return
  fi
  lines=$(printf '%s\n' "$want" | wc -l | tr -d ' ')
  if [[ "$(head -n "$lines" "$file")" == "$want" ]]; then
    echo ok
  elif grep -qF "$BLOCK_BEGIN" "$file"; then
    echo stale
  elif [[ -s $file ]]; then
    echo existing
  else
    echo new
  fi
}

strip_block() {
  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '$0 == b {skip = 1; next} skip && $0 == e {skip = 0; next} !skip'
}

check_dotfiles() {
  local kind state note email repo_email fix insecure dirs dir chmod_cmd
  fix="cd \"$REPO\" && ./install.sh --install dotfiles"
  for kind in zprofile zshrc gitconfig; do
    state=$(dot_state "$kind")
    case $state in
      ok)
        note="loads the repo version first"
        if [[ $kind == gitconfig ]]; then
          email=$(git config --global --includes --get user.email 2>/dev/null)
          repo_email=$(git config --file "$REPO/git/gitconfig" --get user.email)
          [[ -n $email && $email != "$repo_email" ]] && note="$note; user.email is overridden below it ($email)"
        fi
        add_item dotfiles "d:$kind" "~/.$kind" ok "$note"
        ;;
      new) add_item dotfiles "d:$kind" "~/.$kind" todo "will create it" "$fix" apply_dotfile "$kind" ;;
      stale) add_item dotfiles "d:$kind" "~/.$kind" todo "will update the repo block" "$fix" apply_dotfile "$kind" ;;
      existing)
        add_item dotfiles "d:$kind" "~/.$kind" todo \
          "will add the repo block at the top (asks: keep your lines or start clean)" "$fix" apply_dotfile "$kind"
        ;;
    esac
  done

  for kind in zprofile zshrc; do
    if zsh -n "$REPO/zsh/$kind" 2>/dev/null; then
      add_item dotfiles "s:$kind" "zsh/$kind syntax" ok "valid"
    else
      add_item dotfiles "s:$kind" "zsh/$kind syntax" fail "zsh can't parse it" \
        "zsh -n \"$REPO/zsh/$kind\"   (shows the error)"
    fi
  done

  insecure=$(insecure_completion_paths)
  if [[ -z $insecure ]]; then
    add_item dotfiles completion "zsh completion folders" ok "only you can change them"
  else
    dirs='' chmod_cmd='chmod go-w'
    while IFS= read -r dir; do
      dirs="$dirs $dir" chmod_cmd="$chmod_cmd \"$dir\""
    done <<<"$insecure"
    add_item dotfiles completion "zsh completion folders" todo \
      "other users can write to$dirs; will stop that so new shells don't warn" "$chmod_cmd" apply_completion_dirs
  fi
}

# Folders (and their parents) that compinit refuses because other users can write to them.
# Homebrew's installer leaves /opt/homebrew/share writable by the admin group, which makes every
# new shell print "zsh compinit: insecure directories". One path per line, nothing when all is well.
insecure_completion_paths() {
  # shellcheck disable=SC2016
  zsh -fc 'fpath=("$@" $fpath); autoload -Uz compaudit; compaudit 2>/dev/null' zsh "${ZSH_COMPLETION_DIRS[@]}" |
    grep '^/'
}

apply_completion_dirs() {
  local dir failed=''
  while IFS= read -r dir; do
    chmod go-w "$dir" || failed="$failed \"$dir\""
  done < <(insecure_completion_paths)
  if [[ -n $failed ]]; then
    RESULT_REASON="couldn't change the permissions of$failed"
    RESULT_FIX="sudo chmod go-w$failed"
    return 1
  fi
  return 0
}

apply_dotfile() {
  local kind=$1 file state block tmp backup='' keep=1
  file=$(dot_file "$kind")
  state=$(dot_state "$kind")
  block=$(dot_block "$kind")
  [[ $state == ok ]] && return 0

  if [[ $state == existing ]]; then
    ask "~/.$kind already has its own lines. Keep them below the repo block (k) or back it up and start clean (c)? [K/c]"
    case $REPLY_ANSWER in c | C) keep=0 ;; esac
  fi

  tmp=$(mktemp) || return 1
  {
    printf '%s\n' "$block"
    case $state in
      existing) [[ $keep -eq 1 ]] && cat "$file" ;;
      stale) strip_block <"$file" ;;
    esac
  } >"$tmp"

  if [[ -e $file || -L $file ]]; then
    backup="$file.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$file" "$backup" || { rm -f "$tmp"; RESULT_REASON="couldn't back up $file"; return 1; }
  fi
  if ! mv "$tmp" "$file" || ! chmod 644 "$file"; then
    RESULT_REASON="couldn't write $file"
    return 1
  fi
  [[ -n $backup ]] && echo "  backed up the old file to $backup"
  return 0
}
