#!/usr/bin/env bash
set -euo pipefail

mode="${1:---full}"
if [[ "$mode" != "--full" && "$mode" != "--conductor-setup" ]]; then
  echo "Usage: $0 [--full|--conductor-setup]" >&2
  exit 2
fi

echo "Bootstrapping toolchains for Fulcrum-Proofs"
REQUIRED_GO="${REQUIRED_GO_VERSION:-1.24.13}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

warm_lean_cache() {
  if ! command -v lake >/dev/null 2>&1; then
    echo "LEAN_CACHE_WARM_SKIPPED: project-pinned lake is unavailable." >&2
    return 0
  fi
  if ! (cd "$REPO_ROOT/proofs/lean" && lake exe cache get); then
    echo "LEAN_CACHE_WARM_SKIPPED: unable to warm the project-pinned Lean cache." >&2
  fi
}

if [[ "$mode" == "--conductor-setup" ]]; then
  echo "[1/2] Java and TLA+ tools"
else
  echo "[1/4] Java and TLA+ tools"
fi
bash "$SCRIPT_DIR/preflight_model_gate.sh" --java-only
bash "$SCRIPT_DIR/tla_toolchain.sh" --install
bash "$SCRIPT_DIR/preflight_model_gate.sh"

if [[ "$mode" == "--conductor-setup" ]]; then
  echo "[2/2] Best-effort project-pinned Lean cache warm"
  warm_lean_cache
  echo "Bounded Conductor toolchain setup complete"
  exit 0
fi

echo "[2/4] Lean via elan"
if ! command -v elan >/dev/null 2>&1; then
  curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
fi

export PATH="$HOME/.elan/bin:$PATH"
elan toolchain install stable
warm_lean_cache

echo "[3/4] Go version check"
if command -v go >/dev/null 2>&1; then
  GO_VERSION="$(go version | awk '{print $3}' | sed 's/^go//')"
  echo "Detected Go: $GO_VERSION (required: $REQUIRED_GO)"
  if [[ "$GO_VERSION" != "$REQUIRED_GO" ]]; then
    echo "WARNING: Go version mismatch. Use $REQUIRED_GO for reproducible harness behavior." >&2
  fi
else
  echo "go not found in PATH" >&2
fi

echo "[4/4] Python deps"
python3 -m pip install -r requirements.txt

echo "Toolchain bootstrap complete"
