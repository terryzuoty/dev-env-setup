#modify terminal colors
#https://geoff.greer.fm/lscolors/
#https://www.cyberciti.biz/faq/apple-mac-osx-terminal-color-ls-output-option/
#PS1='%n@%m %1~ %# '
#PS1='%n@%m %~ %# '
#For ZSH
#PS1='%B%F{131}%n@%m%f%b %F{220}%1~%b %(?.%F{green}√.%F{red}?%?)%f %# '
PS1='%B%F{131}%n@%m%f%b %F{220}%1~%b %(?.%F{green}√.%F{red}?%?)%f %# '
export CLICOLOR=1
export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx
#export LDFLAGS="-L/usr/local/opt/zlib/lib"
#export CPPFLAGS="-I/usr/local/opt/zlib/include"


#termianl cmd
alias ll="ls -lah"
alias llg="ls -lah | grep"

#aws cli cmd
alias aws_set_profile_engineering="export AWS_PROFILE=engineering"
alias aws_unset_profile="unset AWS_PROFILE"

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

#aws-vault cmd
alias awsvault="aws-vault"

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi


export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"

if command -v pyenv 1>/dev/null 2>&1; 
then 
	export PYENV_ROOT="$HOME/.pyenv";
	export PATH="$PYENV_ROOT/bin:$PATH";
	eval "$(pyenv init --path)";
	eval "$(pyenv init -)"; 
fi
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi
if which pipenv > /dev/null; then eval "$(_PIPENV_COMPLETE=zsh_source pipenv)"; fi
if which aws-vault > /dev/null; then eval "$(aws-vault --completion-script-zsh)"; fi


# Set up GoLand environment
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export GOROOT="$(brew --prefix golang)/libexec"
export PATH=$PATH:$GOPATH/bin:$GOROOT/bin


#temp solution for DBngin
function mysqlport() {
	command mysql --socket /tmp/mysql_$1.sock -uroot
}
