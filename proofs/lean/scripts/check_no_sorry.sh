#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LEAN_PROOFS_DIR="$ROOT/proofs/lean/Proofs"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for no-sorry checks" >&2
  exit 1
fi

if rg -n "\bsorry\b" "$LEAN_PROOFS_DIR"; then
  echo "proof closure check failed: found 'sorry' in Lean proofs" >&2
  exit 1
fi

echo "proof closure check passed: no 'sorry' found"
