#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LEAN_PROOFS_DIR="$ROOT/proofs/lean/Proofs"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for no-sorry checks" >&2
  exit 1
fi

# Known, justified sorry holes tracked in claims/claim_ledger.yaml.
# Each entry is a single exact allowlisted occurrence. The gate fails if the
# count changes, which preserves a zero-new-sorry policy even in files that
# currently contain a documented placeholder.
#
# MixedNashExistence.lean: Kakutani FPT axiomatized; machine-checked proofs
#   exist (harfe/fixed-point-theorems-lean4, math-xmum/Brouwer) but on
#   incompatible toolchain (v4.21-22 vs our v4.29). Claim C-018.
#
# CoordinationEfficiency.lean: fulcrum_poa_bounded composition step;
#   all sub-lemmas (welfare_upper_bound, allModerate_welfare) are sorry-free.
#   Claim C-020.
ALLOWED_OCCURRENCES=(
  "GameTheory/MixedNashExistence.lean:sorry -- Kakutani FPT applied to best-response correspondence"
  "GameTheory/CoordinationEfficiency.lean:sorry -- Follows from welfare_upper_bound and allModerate_welfare"
)

mapfile -t ALL_MATCHES < <(rg -n "\bsorry\b" -g "*.lean" "$LEAN_PROOFS_DIR" || true)
TOTAL_MATCHES=${#ALL_MATCHES[@]}
EXPECTED_TOTAL=${#ALLOWED_OCCURRENCES[@]}

for entry in "${ALLOWED_OCCURRENCES[@]}"; do
  IFS=":" read -r file pattern <<< "$entry"
  COUNT=$({ rg -F -o "$pattern" "$LEAN_PROOFS_DIR/$file" 2>/dev/null || true; } | wc -l | tr -d ' ')
  if [[ "$COUNT" -ne 1 ]]; then
    echo "proof closure check failed: allowlisted sorry occurrence changed in $file" >&2
    printf '%s\n' "${ALL_MATCHES[@]}"
    exit 1
  fi
done

if [[ "$TOTAL_MATCHES" -ne "$EXPECTED_TOTAL" ]]; then
  echo "proof closure check failed: found unauthorized 'sorry' in Lean proofs" >&2
  printf '%s\n' "${ALL_MATCHES[@]}"
  exit 1
fi

echo "=== Allowlisted sorry holes (tracked in claim_ledger.yaml) ==="
for entry in "${ALLOWED_OCCURRENCES[@]}"; do
  IFS=":" read -r file _ <<< "$entry"
  echo "  $file: 1 exact allowlisted sorry"
done

echo "proof closure check passed: no unauthorized sorry found"
