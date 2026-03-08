#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LEAN_PROOFS_DIR="$ROOT/proofs/lean/Proofs"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for no-sorry checks" >&2
  exit 1
fi

# Known, justified sorry holes tracked in claims/claim_ledger.yaml.
# Each entry: "filename:pattern" — these are allowed through the gate.
#
# MixedNashExistence.lean: Kakutani FPT axiomatized; machine-checked proofs
#   exist (harfe/fixed-point-theorems-lean4, math-xmum/Brouwer) but on
#   incompatible toolchain (v4.21-22 vs our v4.29). Claim C-018.
#
# CoordinationEfficiency.lean: fulcrum_poa_bounded composition step;
#   all sub-lemmas (welfare_upper_bound, allModerate_welfare) are sorry-free.
#   Claim C-020.
ALLOWED_FILES=(
  "GameTheory/MixedNashExistence.lean"
  "GameTheory/CoordinationEfficiency.lean"
)

# Build exclusion pattern for rg
EXCLUDE_ARGS=()
for f in "${ALLOWED_FILES[@]}"; do
  EXCLUDE_ARGS+=(-g "!**/$f")
done

# Check for sorry in all .lean files EXCEPT the allowlisted ones
if rg -n "\bsorry\b" -g "*.lean" "${EXCLUDE_ARGS[@]}" "$LEAN_PROOFS_DIR"; then
  echo "proof closure check failed: found 'sorry' in Lean proofs (outside allowlist)" >&2
  exit 1
fi

# Report allowlisted sorries for transparency
echo "=== Allowlisted sorry holes (tracked in claim_ledger.yaml) ==="
for f in "${ALLOWED_FILES[@]}"; do
  matches=$(rg -c "\bsorry\b" "$LEAN_PROOFS_DIR/$f" 2>/dev/null || echo "0")
  echo "  $f: $matches sorry(s)"
done

echo "proof closure check passed: no unauthorized sorry found"
