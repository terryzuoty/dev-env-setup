export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"

#termianl cmd
alias ll="ls -lah"
alias llg="ls -lah | grep"

#git cmd
alias ga="git commit --amend"
alias gadd="git add"
alias gch="git checkout"
alias gchb="git checkout -b"
alias gbr="git branch"
alias gbrv="git branch -vv"
alias gc="git commit -m"
alias gcl="git clone"
alias gl="git log"
alias gpull="git pull --rebase"
alias gpush="git push"
alias gft="git fetch origin"
alias gr="git reset"
alias grs="git reset --soft"
alias grh="git reset --hard"
alias grb="git rebase"
alias gs="git status"
alias gbc="{ read branch; gchb $branch; gch $branch; } <&0"

#docker cmd
alias dockercomp="docker-compose"


if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi

#modify terminal colors
#https://geoff.greer.fm/lscolors/
#https://www.cyberciti.biz/faq/apple-mac-osx-terminal-color-ls-output-option/
#PS1='%n@%m %1~ %# '
#PS1='%n@%m %~ %# '
PS1='%B%F{131}%n@%m%f%b %F{220}%1~%b %(?.%F{green}√.%F{red}?%?)%f %# '
export CLICOLOR=1
export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx


