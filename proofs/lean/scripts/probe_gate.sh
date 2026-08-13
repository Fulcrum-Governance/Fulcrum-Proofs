#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LEAN_DIR="$ROOT/proofs/lean"
REPORT_DIR="$LEAN_DIR/reports"
mkdir -p "$REPORT_DIR"

export PATH="$HOME/.elan/bin:$PATH"

if ! command -v lake >/dev/null 2>&1; then
  echo "lake not found; install Lean toolchain (elan/lake)." >&2
  exit 1
fi

cd "$LEAN_DIR"
LOG="$REPORT_DIR/probe-gate.log"
: > "$LOG"

echo "[probe-gate] fixture must bite (implicit sorryAx, grep-invisible)" | tee -a "$LOG"
if lake env lean probes/fixtures/implicit_sorry_fixture.lean >>"$LOG" 2>&1; then
  echo "[probe-gate] FAIL: fixture elaborated cleanly — sorryAx gate does not bite" | tee -a "$LOG" >&2
  exit 1
fi
echo "[probe-gate] fixture bit as expected" | tee -a "$LOG"

echo "[probe-gate] kernel-level sorryAx sweep over all Fulcrum declarations" | tee -a "$LOG"
lake env lean probes/check_sorry.lean 2>&1 | tee -a "$LOG"

echo "[probe-gate] axiom-profile assertions vs claims/theorem_inventory.yaml" | tee -a "$LOG"
lake env lean probes/check_central_axioms.lean 2>&1 | tee -a "$LOG"

echo "[probe-gate] FUL-502 canonical/correspondence axiom profiles" | tee -a "$LOG"
lake env lean probes/check_exact_poa_axioms.lean 2>&1 | tee -a "$LOG"

echo "probe gate complete" | tee -a "$LOG"
