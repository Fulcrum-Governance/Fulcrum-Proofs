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

if ! command -v rg >/dev/null 2>&1; then
  echo "rg not found; install ripgrep." >&2
  exit 1
fi

pushd "$LEAN_DIR" >/dev/null

echo "[proof-gate] checking for forbidden placeholders"
"$LEAN_DIR/scripts/check_no_sorry.sh" | tee "$REPORT_DIR/no-sorry-check.log"

echo "[proof-gate] running lake build"
# Explicit target: bare `lake build` was a no-op before the lakefile gained
# @[default_target] ("0 jobs" green without elaborating a single proof).
lake build Proofs | tee "$REPORT_DIR/lake-build.log"

if grep -q "(0 jobs)" "$REPORT_DIR/lake-build.log" && [ ! -f .lake/build/lib/lean/Proofs.olean ]; then
  echo "lake build did no work and no library olean exists — hollow gate" >&2
  exit 1
fi

echo "[proof-gate] extracting theorem inventory"
rg -n "^theorem\\s+" Proofs \
  | awk -F: '{print $1":"$2":"$3}' \
  > "$REPORT_DIR/theorem-inventory.txt"

cat > "$REPORT_DIR/dependency-map.txt" <<MAP
Proofs.lean imports:
$(rg -n "^import " Proofs.lean || true)

Module imports:
$(rg -n "^import " Proofs/*.lean || true)
MAP

required=(
  "thm_budget_local"
  "thm_privilege_static"
  "thm_temporal_conservation_spec"
  "trust_monotone_decreasing"
  "trust_guaranteed_termination"
  "capped_prior_strict_responsiveness"
  "governed_kernel_pre_execution_safety"
  "mixed_nash_exists"
  "fulcrum_poa_bounded"
  "constrained_poa_exact"
  "budget_enforcement_grounds_game"
  "rlm_depth_bounded"
)

for t in "${required[@]}"; do
  if ! rg -n "theorem\\s+$t\\b" Proofs >/dev/null; then
    echo "missing required theorem: $t" >&2
    exit 1
  fi
done

printf "%s\n" "${required[@]}" > "$REPORT_DIR/required-theorems.txt"

popd >/dev/null

echo "proof replay complete"
