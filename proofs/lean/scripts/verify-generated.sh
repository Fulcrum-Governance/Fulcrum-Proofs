#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GENERATED_DIR="$ROOT/proofs/lean/Proofs/Generated"

if ! command -v lean >/dev/null 2>&1; then
  echo "lean binary is required to verify generated proofs" >&2
  exit 1
fi

if [[ ! -d "$GENERATED_DIR" ]]; then
  echo "generated proof directory not found: $GENERATED_DIR" >&2
  exit 1
fi

mapfile -t GENERATED_FILES < <(find "$GENERATED_DIR" -type f -name "*.lean" | sort)

if [[ ${#GENERATED_FILES[@]} -eq 0 ]]; then
  echo "no generated Lean proofs found in $GENERATED_DIR"
  exit 0
fi

echo "verifying ${#GENERATED_FILES[@]} generated Lean proof(s)..."
for file in "${GENERATED_FILES[@]}"; do
  echo "- lean $file"
  lean "$file"
done

echo "generated proof verification passed"
