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

pushd "$LEAN_DIR" >/dev/null

echo "[proof-gate] running lake build"
lake build | tee "$REPORT_DIR/lake-build.log"

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

popd >/dev/null

echo "proof replay complete"
