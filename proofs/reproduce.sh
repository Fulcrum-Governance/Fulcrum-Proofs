#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LEAN_ROOT="$SCRIPT_DIR/lean"
EXPECTED_DOC="$LEAN_ROOT/expected_axioms.md"
PROBE_FILE="probes/check_central_axioms.lean"
EXACT_POA_PROBE_FILE="probes/check_exact_poa_axioms.lean"
NO_SORRY_SCRIPT="scripts/check_no_sorry.sh"

extract_expected_axioms() {
  awk '
    /^```text$/ { in_block = 1; next }
    /^```$/ && in_block { exit }
    in_block { print }
  ' "$EXPECTED_DOC"
}

echo "==> [1/4] lake build"
if ! (
  cd "$LEAN_ROOT" &&
  lake build
); then
  echo "ERROR: lake build failed" >&2
  exit 1
fi

echo "==> [2/4] no-sorry gate"
if ! (
  cd "$LEAN_ROOT" &&
  bash "$NO_SORRY_SCRIPT"
); then
  echo "ERROR: sorryAx drift detected" >&2
  exit 4
fi

echo "==> [3/4] central axiom-profile gate"
live_output="$(mktemp)"
expected_output="$(mktemp)"
trap 'rm -f "$live_output" "$expected_output"' EXIT

extract_expected_axioms > "$expected_output"
if [[ ! -s "$expected_output" ]]; then
  echo "ERROR: expected axiom baseline missing from $EXPECTED_DOC" >&2
  exit 3
fi

if ! (
  cd "$LEAN_ROOT" &&
  lake env lean "$PROBE_FILE"
) > "$live_output"; then
  echo "ERROR: axiom probe failed" >&2
  cat "$live_output" >&2
  exit 3
fi

if ! diff -u "$expected_output" "$live_output"; then
  echo "ERROR: axiom profile drift detected" >&2
  exit 3
fi

echo "==> [4/4] exact PoA cone and correspondence profiles"
if ! (
  cd "$LEAN_ROOT" &&
  lake env lean "$EXACT_POA_PROBE_FILE"
); then
  echo "ERROR: exact PoA axiom profile drift detected" >&2
  exit 3
fi

echo "OK: all integrity gates passed"
