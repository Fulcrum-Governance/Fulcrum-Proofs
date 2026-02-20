#!/usr/bin/env bash
set -euo pipefail

echo "Bootstrapping toolchains for Fulcrum-Proofs"
REQUIRED_GO="${REQUIRED_GO_VERSION:-1.24.13}"

echo "[1/4] Lean via elan"
if ! command -v elan >/dev/null 2>&1; then
  curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y
fi

export PATH="$HOME/.elan/bin:$PATH"
elan toolchain install stable

echo "[2/4] TLA+ tools"
mkdir -p models/tla/tools
if [[ ! -f models/tla/tools/tla2tools.jar ]]; then
  echo "Download latest tla2tools.jar into models/tla/tools/"
fi

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
