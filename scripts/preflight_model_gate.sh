#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_java() {
  if [[ -n "${TLA_JAVA_BIN:-}" ]]; then
    printf '%s\n' "$TLA_JAVA_BIN"
    return
  fi
  if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
    printf '%s\n' "$JAVA_HOME/bin/java"
    return
  fi
  if [[ -x "/opt/homebrew/opt/openjdk@17/bin/java" ]]; then
    printf '%s\n' "/opt/homebrew/opt/openjdk@17/bin/java"
    return
  fi
  if command -v java >/dev/null 2>&1; then
    command -v java
    return
  fi
  return 1
}

canonicalize_executable() {
  local executable="$1"
  local executable_directory
  executable_directory="$(cd "$(dirname "$executable")" && pwd -P)"
  printf '%s/%s\n' "$executable_directory" "$(basename "$executable")"
}

mode="${1:---all}"
if [[ "$mode" != "--all" && "$mode" != "--java-only" && "$mode" != "--java-path" ]]; then
  echo "Usage: $0 [--all|--java-only|--java-path]" >&2
  exit 2
fi

JAVA_BIN="$(find_java || true)"
if [[ -z "$JAVA_BIN" || ! -x "$JAVA_BIN" ]]; then
  echo "TLA_JAVA_MISSING: Java 17+ is required for TLC. Install a JDK, set JAVA_HOME, or set TLA_JAVA_BIN." >&2
  exit 1
fi
JAVA_BIN="$(canonicalize_executable "$JAVA_BIN")"

java_version="$("$JAVA_BIN" -version 2>&1 | sed -nE 's/.*version "([0-9]+)(\.[0-9]+)?.*/\1/p' | head -n 1 || true)"
if [[ -z "$java_version" || "$java_version" -lt 17 ]]; then
  echo "TLA_JAVA_UNSUPPORTED: $JAVA_BIN must report Java 17 or later for TLC." >&2
  exit 1
fi

if [[ "$mode" == "--java-path" ]]; then
  printf '%s\n' "$JAVA_BIN"
else
  echo "TLA_JAVA_OK: $JAVA_BIN (Java $java_version)"
fi
if [[ "$mode" == "--all" ]]; then
  bash "$ROOT/scripts/tla_toolchain.sh" --verify
fi
