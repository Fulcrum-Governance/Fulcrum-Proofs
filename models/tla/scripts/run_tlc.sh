#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SPEC_DIR="$ROOT/models/tla/specs"
CFG_DIR="$ROOT/models/tla/configs"
TRACE_DIR="$ROOT/models/tla/traces"
REPORT_DIR="$ROOT/models/tla/reports"
TOOLS_DIR="$ROOT/models/tla/tools"

mkdir -p "$TRACE_DIR" "$REPORT_DIR"

TLC_JAR="$TOOLS_DIR/tla2tools.jar"
if [[ ! -f "$TLC_JAR" ]]; then
  echo "Missing $TLC_JAR" >&2
  echo "Download from https://github.com/tlaplus/tlaplus/releases and place tla2tools.jar in models/tla/tools/." >&2
  exit 1
fi

if [[ -x "/opt/homebrew/opt/openjdk@17/bin/java" ]]; then
  export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
fi

java -version >/dev/null 2>&1 || { echo "java not found" >&2; exit 1; }

pushd "$SPEC_DIR" >/dev/null
cfgs=(
  "$CFG_DIR/GatewaySafetySmall.cfg"
  "$CFG_DIR/GatewaySafety.cfg"
  "$CFG_DIR/GatewaySafetyMedium.cfg"
)

for cfg in "${cfgs[@]}"; do
  if [[ ! -f "$cfg" ]]; then
    echo "Missing config: $cfg" >&2
    exit 1
  fi

  cfg_name="$(basename "$cfg" .cfg)"
  log_file="$REPORT_DIR/tlc-${cfg_name}.log"
  echo "[model-gate] running TLC with $cfg_name"
  java -cp "$TLC_JAR" tlc2.TLC -cleanup -deadlock -config "$cfg" GatewaySafety \
    | tee "$log_file"
done
popd >/dev/null

echo "TLC model check complete"
