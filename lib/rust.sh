# shellcheck shell=bash
# The Rust toolchain. Homebrew installs rustup but no toolchain; rustup downloads that itself.
# Homebrew doesn't link rustup into /opt/homebrew/bin, so it's called by its full path.

RUSTUP=/opt/homebrew/opt/rustup/bin/rustup
RUST_TOOLCHAIN=stable

# The default toolchain's name, or nothing when rustup has none yet.
rust_default() {
  "$RUSTUP" default 2>/dev/null | sed -nE 's/^([^[:space:]]+).*/\1/p' | head -n 1
}

check_rust() {
  local current fix
  fix="$RUSTUP default $RUST_TOOLCHAIN"
  if [[ -x $RUSTUP ]]; then
    current=$(rust_default)
    if [[ -n $current ]]; then
      add_item rust rust-toolchain "Rust toolchain" ok "default: $current"
    else
      add_item rust rust-toolchain "Rust toolchain" todo "will install $RUST_TOOLCHAIN and make it the default" \
        "$fix" apply_rust_toolchain
    fi
  elif [[ $(item_state f:rustup) == todo ]]; then
    add_item rust rust-toolchain "Rust toolchain" todo "will install $RUST_TOOLCHAIN once rustup is installed" \
      "brew install rustup\n$fix" apply_rust_toolchain
  else
    add_item rust rust-toolchain "Rust toolchain" manual "needs rustup, which isn't installed" \
      "brew install rustup\n$fix"
  fi
}

apply_rust_toolchain() {
  if [[ ! -x $RUSTUP ]]; then
    RESULT_REASON="rustup isn't installed"
    RESULT_FIX="brew install rustup\n$RUSTUP default $RUST_TOOLCHAIN"
    return 2
  fi
  "$RUSTUP" default "$RUST_TOOLCHAIN" && return 0
  RESULT_REASON="rustup default $RUST_TOOLCHAIN failed (see the output above)"
  return 1
}
