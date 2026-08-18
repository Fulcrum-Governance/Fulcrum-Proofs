#!/usr/bin/env bash
set -euo pipefail

# Keep this pin synchronized with README.md when intentionally upgrading TLC.
TLA_TOOLS_VERSION="1.7.4"
TLA_TOOLS_SHA256="936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
TLA_TOOLS_URL="https://github.com/tlaplus/tlaplus/releases/download/v${TLA_TOOLS_VERSION}/tla2tools.jar"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${TLA_TOOLS_DIR:-$ROOT/models/tla/tools}"
TLC_JAR="$TOOLS_DIR/tla2tools.jar"

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "TLA_SHA256_TOOL_MISSING: install shasum or sha256sum to verify TLC." >&2
    return 1
  fi
}

verify() {
  if [[ ! -f "$TLC_JAR" ]]; then
    echo "TLA_JAR_MISSING: expected $TLC_JAR (TLA+ v${TLA_TOOLS_VERSION}). Run bash scripts/bootstrap_toolchains.sh." >&2
    return 1
  fi

  local actual
  actual="$(sha256_file "$TLC_JAR")"
  if [[ "$actual" != "$TLA_TOOLS_SHA256" ]]; then
    echo "TLA_JAR_CHECKSUM_MISMATCH: expected $TLA_TOOLS_SHA256, got $actual for $TLC_JAR." >&2
    echo "Re-run bash scripts/bootstrap_toolchains.sh to install the verified TLA+ v${TLA_TOOLS_VERSION} asset." >&2
    return 1
  fi

  echo "TLA_TOOLS_OK: v${TLA_TOOLS_VERSION} $TLC_JAR"
}

install() {
  mkdir -p "$TOOLS_DIR"
  if [[ -f "$TLC_JAR" ]] && verify >/dev/null; then
    echo "TLA_TOOLS_OK: verified existing v${TLA_TOOLS_VERSION} $TLC_JAR"
    return 0
  fi

  local temporary
  temporary="$(mktemp "$TOOLS_DIR/.tla2tools.jar.XXXXXX")"
  trap 'rm -f "$temporary"' RETURN
  echo "Downloading verified TLA+ v${TLA_TOOLS_VERSION} tools"
  curl --fail --location --silent --show-error --retry 3 --output "$temporary" "$TLA_TOOLS_URL"

  local actual
  actual="$(sha256_file "$temporary")"
  if [[ "$actual" != "$TLA_TOOLS_SHA256" ]]; then
    echo "TLA_DOWNLOAD_CHECKSUM_MISMATCH: expected $TLA_TOOLS_SHA256, got $actual from $TLA_TOOLS_URL." >&2
    return 1
  fi

  mv "$temporary" "$TLC_JAR"
  trap - RETURN
  echo "TLA_TOOLS_OK: installed verified v${TLA_TOOLS_VERSION} $TLC_JAR"
}

case "${1:---verify}" in
  --verify) verify ;;
  --install) install ;;
  *)
    echo "Usage: $0 [--verify|--install]" >&2
    exit 2
    ;;
esac
