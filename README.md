# dev-env-setup

Checks an Apple silicon Mac against my dev setup and installs what's missing: Homebrew apps and
tools, Node and Rust, zsh, git, Terminal and iTerm2. Safe to run any number of times.

## New Mac

1. Install Apple's command line tools (this also gives you `git`):
   ```bash
   xcode-select --install
   ```
2. Install Homebrew:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Clone this repo. Use HTTPS, since the Mac has no SSH key yet. Keep it where you clone it:
   `~/.zshrc`, `~/.zprofile` and `~/.gitconfig` point at this folder.
   ```bash
   git clone https://github.com/terryzuoty/dev-env-setup.git ~/dev-env-setup
   cd ~/dev-env-setup
   ```
4. Check, then install:
   ```bash
   ./install.sh
   ./install.sh --install
   ```
5. Work through the **To do** list it prints, then run `./install.sh` again until everything is ✓.

## Usage

| Command | What it does |
|---|---|
| `./install.sh` | Checks and reports. Changes nothing. |
| `./install.sh --install` | Checks, reports, asks y/n, applies what's missing, then checks again. |
| `./install.sh [--install] <step>…` | Only the named steps: `brew`, `gcloud`, `rust`, `node`, `languages`, `dotfiles`, `terminal`, `iterm2`, `manual`. |

Exit code: `0` when everything is in place, `1` when something isn't, `2` when Apple's command line
tools or Homebrew are missing (it stops right away and tells you how to install them).

During `--install` it only asks you something when a step can be done with your help: your Mac
password for casks that need it, whether to keep your existing lines in a home config file, and
whether to quit an app whose settings it changes. Anything it can't do is skipped, logged with the
reason, and listed at the end with the steps to do it yourself. The summary is also saved to
`~/Library/Logs/dev-env-setup/`.

## What it checks

- **Homebrew**: every formula and cask in [`Brewfile`](Brewfile). An app already installed some other
  way counts as installed. A formula that is only there as another package's dependency gets marked
  as wanted, so `brew autoremove` keeps it.
- **gcloud components**: `gke-gcloud-auth-plugin`.
- **Rust**: rustup (from the Brewfile) has a default toolchain. If it has none, `stable` is installed
  and made the default.
- **Node**: fnm (from the Brewfile) has a default Node version. If it has none, the latest LTS is
  installed and becomes the default. If you installed Homebrew's own `node`, it's listed for you to
  remove, so there's only one `node`.
- **Languages**: Go, Rust (`cargo`), Python, Python with `uv`, Node.js (with `npm`) and Java (`javac`)
  each run a small program, using the same tools your shell does. It runs in a temporary folder
  that's deleted afterwards, with build caches kept in that folder and nothing downloaded, so
  checking leaves nothing behind. It takes a few seconds; run it alone with `./install.sh languages`.
- **Shell and git**: `~/.zprofile`, `~/.zshrc` and `~/.gitconfig` load [`zsh/zprofile`](zsh/zprofile),
  [`zsh/zshrc`](zsh/zshrc) and [`git/gitconfig`](git/gitconfig) first. Only you can change the
  folders zsh loads completions from; otherwise every new shell stops with
  `zsh compinit: insecure directories`. Homebrew's installer leaves `/opt/homebrew/share` writable by
  the admin group, so a new Mac needs this once.
- **Terminal**: default and new-window profile is Clear Dark, or Pro on a macOS without Clear Dark.
- **iTerm2**: the [`iterm2/profile.json`](iterm2/profile.json) profile (SF Mono 14) is installed and
  is the default, and iTerm2's theme is Dark, so it stays dark when macOS switches to light mode.
  Setting the theme or default profile needs iTerm2 closed, so the script asks to quit it.
- **Manual items**: three-finger drag, a GitHub SSH key, `gh` login, `gcloud` login. These drop off
  the list once you've done them.

## Home config files

`~/.zprofile`, `~/.zshrc` and `~/.gitconfig` stay normal files with this block at the top:

```
# >>> dev-env-setup >>>
[[ -f "…/zsh/zshrc" ]] && source "…/zsh/zshrc"
# <<< dev-env-setup <<<
```

Anything below the block is specific to that Mac and overrides the repo. That's where apps like
Docker Desktop add their own lines, and where you put anything that shouldn't be shared. The old
file is backed up next to it (`.zshrc.backup-<date>`) whenever the script changes it.

If you move the repo, run `./install.sh --install dotfiles` to point the blocks at the new folder.

## Shell shortcuts

- **Ctrl-R**: fuzzy-search your history (fzf). Type any part of a command, ↑/↓ to pick, Enter to use it.
- **Ctrl-T**: pick a file or folder and paste its path into the command line (fzf).
- **→** (or End): accept the grey suggestion from history as you type (zsh-autosuggestions).
- A command shows green when it exists and red when it doesn't, before you press Enter
  (zsh-syntax-highlighting).
- `rg <text>` searches code and `fd <name>` finds files; both skip what `.gitignore` lists.

## Changing the setup

- **Add an app or tool**: add a line to `Brewfile`, then `./install.sh --install brew`.
- **Remove an app or tool**: delete its line from `Brewfile`, then `brew uninstall <name>` (add
  `--cask` for apps), and `brew cleanup --prune=all` to clear Homebrew's download cache.
  `brew uninstall` also removes dependencies nothing else needs.
- **Shell**: edit `zsh/zshrc` and open a new terminal window.
- **Node**: a project picks its version with `.nvmrc` or `.node-version`, and fnm switches to it when
  you `cd` in. To move the default to a newer LTS: `fnm install --lts && fnm default lts-latest`.
- **Java**: `JAVA_HOME` points at JDK 25 from the `temurin@25` cask. A project that needs another
  version: add that cask (e.g. `temurin@21`), then `export JAVA_HOME=$(/usr/libexec/java_home -v 21)`
  in that shell. For the next LTS, add its cask, change `-v 25` in `zsh/zshrc`, then uninstall the
  old cask.
- **iTerm2 profile**: edit `iterm2/profile.json`, then `./install.sh --install iterm2`.

## Layout

```
install.sh          entry point
Brewfile            formulae and casks
zsh/zprofile        Homebrew on PATH
zsh/zshrc           prompt, history, PATH for python/go/rust/uv tools, fnm, JAVA_HOME, aliases,
                    completions, fzf keys, autosuggestions, syntax highlighting
git/gitconfig       name and email
iterm2/profile.json iTerm2 profile
lib/                the checks behind each step
```
