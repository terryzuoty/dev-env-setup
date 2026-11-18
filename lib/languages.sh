# shellcheck shell=bash
# Each language builds and runs a tiny program in a temporary folder that's deleted afterwards.
# Build caches go into that folder too and nothing is downloaded, so a check leaves nothing behind.
# The tools are found where zsh/zshrc puts them on PATH. Uses RUSTUP and FNM from rust.sh and node.sh.

LANGUAGES=(go rust python uv node java)
GO_BIN=/opt/homebrew/bin/go
PYTHON_BIN=/opt/homebrew/opt/python/libexec/bin/python
UV_BIN=/opt/homebrew/bin/uv
RUSTUP_BIN_DIR=/opt/homebrew/opt/rustup/bin
JAVA_VERSION=25

lang_label() {
  case $1 in
    go) echo "Go" ;;
    rust) echo "Rust" ;;
    python) echo "Python" ;;
    uv) echo "Python with uv" ;;
    node) echo "Node.js" ;;
    java) echo "Java" ;;
  esac
}

# lang_ready id -> 0 when the toolchain is there to test
lang_ready() {
  case $1 in
    go) [[ -x $GO_BIN ]] ;;
    rust) [[ -x $RUSTUP && -n $(rust_default) ]] ;;
    python) [[ -x $PYTHON_BIN ]] ;;
    uv) [[ -x $UV_BIN && -x $PYTHON_BIN ]] ;;
    node) [[ -x $FNM && -n $(node_default) ]] ;;
    java) /usr/libexec/java_home -v "$JAVA_VERSION" >/dev/null 2>&1 ;;
  esac
}

# The item that installs the toolchain, to tell whether this run will install it.
lang_dep() {
  case $1 in
    go) echo f:go ;;
    rust) echo rust-toolchain ;;
    python) echo f:python ;;
    uv) echo f:uv ;;
    node) echo node-default ;;
    java) echo "c:temurin@$JAVA_VERSION" ;;
  esac
}

lang_install_fix() {
  case $1 in
    rust) echo "cd \"$REPO\" && ./install.sh --install brew rust" ;;
    node) echo "cd \"$REPO\" && ./install.sh --install brew node" ;;
    *) echo "cd \"$REPO\" && ./install.sh --install brew" ;;
  esac
}

# Each test runs in a subshell inside the folder it's given and, on success, ends with the line
# "hello from <id> <version>".
lang_test_go() (
  cd "$1" &&
    printf 'package main\n\nimport (\n\t"fmt"\n\t"runtime"\n)\n\nfunc main() { fmt.Println("hello from go", runtime.Version()) }\n' >main.go &&
    GOCACHE="$1/cache" GOTOOLCHAIN=local "$GO_BIN" run main.go
)

lang_test_rust() (
  export PATH="$RUSTUP_BIN_DIR:$PATH" CARGO_HOME="$1/cargo-home"
  cd "$1" && cargo new --quiet --vcs none hello && cd hello &&
    printf 'fn main() {\n    println!("hello from rust");\n}\n' >src/main.rs &&
    out=$(cargo run --quiet --offline) && echo "$out" && [[ $out == "hello from rust" ]] &&
    echo "hello from rust $(rustc --version | cut -d' ' -f2)"
)

lang_test_python() (
  "$PYTHON_BIN" -c 'import platform; print("hello from python", platform.python_version())'
)

lang_test_uv() (
  cd "$1" && UV_CACHE_DIR="$1/cache" UV_PYTHON_DOWNLOADS=never UV_NO_CONFIG=1 \
    "$UV_BIN" run --no-project --quiet python -c 'import platform; print("hello from uv", platform.python_version())'
)

lang_test_node() (
  export NPM_CONFIG_UPDATE_NOTIFIER=false
  out=$("$FNM" exec --using=default node -e 'console.log("hello from node " + process.version)') &&
    npm=$("$FNM" exec --using=default npm --version) && echo "$out, npm $npm"
)

lang_test_java() (
  home=$(/usr/libexec/java_home -v "$JAVA_VERSION") && cd "$1" &&
    printf 'public class Hello {\n    public static void main(String[] args) {\n        System.out.println("hello from java " + Runtime.version());\n    }\n}\n' >Hello.java &&
    "$home/bin/javac" -J-XX:-UsePerfData Hello.java && "$home/bin/java" -XX:-UsePerfData -cp . Hello
)

# lang_run id -> runs the test in a new temporary folder, deletes the folder, prints the output
lang_run() {
  local dir out rc
  dir=$(mktemp -d "${TMPDIR:-/tmp}/dev-env-setup-$1.XXXXXX") || return 1
  out=$("lang_test_$1" "$dir" 2>&1)
  rc=$?
  [[ -n $dir && -d $dir ]] && rm -rf "$dir"
  printf '%s' "$out"
  return $rc
}

# lang_passed id output -> 0 when the last line is the test's hello line
lang_passed() {
  [[ $(printf '%s\n' "$2" | tail -n 1) == "hello from $1"* ]]
}

lang_failure_fix() {
  printf 'Last lines of its output:\n%s\nAfter fixing it: cd "%s" && ./install.sh languages' \
    "$(printf '%s\n' "$2" | tail -n 6 | sed 's/^/  /; s/\\/\//g')" "$REPO"
}

check_languages() {
  local id label out last
  for id in "${LANGUAGES[@]}"; do
    label=$(lang_label "$id")
    if ! lang_ready "$id"; then
      if [[ $(item_state "$(lang_dep "$id")") == todo ]]; then
        add_item languages "l:$id" "$label" todo "will run a small program in it once it's installed" \
          "$(lang_install_fix "$id")" apply_language "$id"
      else
        add_item languages "l:$id" "$label" manual "not installed yet" "$(lang_install_fix "$id")"
      fi
      continue
    fi
    out=$(lang_run "$id")
    if lang_passed "$id" "$out"; then
      last=$(printf '%s\n' "$out" | tail -n 1)
      add_item languages "l:$id" "$label" ok "ran a small program: ${last#"hello from $id "}"
    else
      add_item languages "l:$id" "$label" fail "couldn't run a small program" "$(lang_failure_fix "$id" "$out")"
    fi
  done
}

apply_language() {
  local out
  if ! lang_ready "$1"; then
    RESULT_REASON="$(lang_label "$1") isn't installed"
    RESULT_FIX=$(lang_install_fix "$1")
    return 2
  fi
  out=$(lang_run "$1")
  if lang_passed "$1" "$out"; then
    printf '  %s\n' "$(printf '%s\n' "$out" | tail -n 1)"
    return 0
  fi
  RESULT_REASON="couldn't run a small program"
  RESULT_FIX=$(lang_failure_fix "$1" "$out")
  return 1
}
