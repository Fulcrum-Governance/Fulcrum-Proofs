#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SPEC_DIR="$ROOT/models/tla/specs"
CFG_DIR="$ROOT/models/tla/configs"
TRACE_DIR="${TLA_TRACE_DIR:-$ROOT/models/tla/traces}"
REPORT_DIR="${TLA_REPORT_DIR:-$ROOT/models/tla/reports}"

JAVA_BIN="$(bash "$ROOT/scripts/preflight_model_gate.sh" --java-path)"
mkdir -p "$TRACE_DIR" "$REPORT_DIR"
TRACE_DIR="$(cd "$TRACE_DIR" && pwd -P)"
REPORT_DIR="$(cd "$REPORT_DIR" && pwd -P)"

TLC_JAR="$(bash "$ROOT/scripts/tla_toolchain.sh" --resolve)"

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
  "$JAVA_BIN" -cp "$TLC_JAR" tlc2.TLC -cleanup -deadlock -config "$cfg" GatewaySafety \
    | tee "$log_file"
done
popd >/dev/null

echo "TLC model check complete"
