#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DEFAULT="/Users/td/ConceptDev/Projects/Fulcrum"
SOURCE="$SOURCE_DEFAULT"

usage() {
  echo "Usage: $0 [--source <fulcrum_repo_path>]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -e "$SOURCE/.git" ]]; then
  echo "Source repo not found: $SOURCE" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required" >&2
  exit 1
fi

mkdir -p "$ROOT/contracts/proto" "$ROOT/contracts/snapshots"

# Sync proto tree
rsync -a --delete \
  --exclude ".DS_Store" \
  --exclude "Icon?" \
  "$SOURCE/proto/fulcrum/" "$ROOT/contracts/proto/fulcrum/"

# Sync selected snapshots
SNAP_DIR="$ROOT/contracts/snapshots"
rm -rf "$SNAP_DIR/interfaces"
mkdir -p "$SNAP_DIR/interfaces"

for f in \
  "internal/workflow/policy.go" \
  "internal/policyengine/evaluator.go" \
  "internal/policyengine/interceptors.go" \
  "internal/eventstore/README.md"; do
  if [[ -f "$SOURCE/$f" ]]; then
    mkdir -p "$SNAP_DIR/interfaces/$(dirname "$f")"
    cp "$SOURCE/$f" "$SNAP_DIR/interfaces/$f"
  fi
done

SRC_SHA="$(git -C "$SOURCE" rev-parse HEAD)"
SRC_REF="$(git -C "$SOURCE" rev-parse --abbrev-ref HEAD)"
SYNC_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$ROOT/contracts/snapshots/version_manifest.yaml" <<MANIFEST
version: 1
source_repo: $SOURCE
source_branch: $SRC_REF
source_commit_sha: $SRC_SHA
synced_at: $SYNC_TIME
notes: contract-coupled import from Fulcrum
MANIFEST

echo "Contracts synced from $SOURCE @ $SRC_SHA"
