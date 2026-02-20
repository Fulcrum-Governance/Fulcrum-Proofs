#!/usr/bin/env python3
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "contracts/snapshots/version_manifest.yaml"
PROTO_ROOT = ROOT / "contracts/proto/fulcrum"

SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def main() -> int:
    if not MANIFEST.exists():
        print("contracts manifest missing: contracts/snapshots/version_manifest.yaml", file=sys.stderr)
        return 1

    doc = yaml.safe_load(MANIFEST.read_text(encoding="utf-8")) or {}
    required = ["version", "source_repo", "source_branch", "source_commit_sha", "synced_at"]
    missing = [k for k in required if not doc.get(k)]
    if missing:
        print(f"contracts manifest missing keys: {', '.join(missing)}", file=sys.stderr)
        return 1

    sha = str(doc["source_commit_sha"]).strip()
    if not SHA_RE.match(sha):
        print("contracts manifest has invalid source_commit_sha", file=sys.stderr)
        return 1

    if not PROTO_ROOT.exists():
        print("contracts/proto/fulcrum is missing; run contracts sync", file=sys.stderr)
        return 1

    proto_files = list(PROTO_ROOT.rglob("*.proto"))
    if not proto_files:
        print("contracts/proto/fulcrum has no .proto files; run contracts sync", file=sys.stderr)
        return 1

    print(f"contracts manifest check passed: commit={sha} proto_files={len(proto_files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
