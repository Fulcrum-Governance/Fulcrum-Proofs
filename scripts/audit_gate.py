#!/usr/bin/env python3
import os
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CLAIM_LEDGER = ROOT / "claims/claim_ledger.yaml"


def main():
    strict = os.getenv("STRICT_AUDIT_GATE", "0") == "1"

    if not CLAIM_LEDGER.exists():
        print("claim ledger missing")
        return 1 if strict else 0

    ledger = yaml.safe_load(CLAIM_LEDGER.read_text(encoding="utf-8"))
    entries = ledger.get("entries", [])

    incomplete = [e for e in entries if e.get("status") == "incomplete"]
    refuted = [e for e in entries if e.get("status") == "refuted"]

    print(f"claims: total={len(entries)} incomplete={len(incomplete)} refuted={len(refuted)}")

    # Bootstrap mode: report without failing.
    if not strict:
        print("audit gate in bootstrap mode (STRICT_AUDIT_GATE=0)")
        return 0

    # Strict mode target: no refuted, and no incomplete for non-empirical claims.
    if refuted:
        print("strict audit gate failed: refuted claims present", file=sys.stderr)
        return 1

    non_empirical_open = [
        e for e in incomplete if e.get("type") in {"formal", "hybrid"}
    ]
    if non_empirical_open:
        print("strict audit gate failed: non-empirical claims still incomplete", file=sys.stderr)
        return 1

    print("strict audit gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
