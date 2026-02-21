#!/usr/bin/env python3
import os
import sys
from datetime import date
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CLAIM_LEDGER = ROOT / "claims/claim_ledger.yaml"
WAIVERS = ROOT / "claims/waivers.yaml"


def main():
    strict = os.getenv("STRICT_AUDIT_GATE", "0") == "1"

    if not CLAIM_LEDGER.exists():
        print("claim ledger missing")
        return 1 if strict else 0

    ledger = yaml.safe_load(CLAIM_LEDGER.read_text(encoding="utf-8"))
    entries = ledger.get("entries", [])

    incomplete = [e for e in entries if e.get("status") == "incomplete"]
    refuted = [e for e in entries if e.get("status") == "refuted"]
    today = date.today()

    waiver_map = {}
    if WAIVERS.exists():
        doc = yaml.safe_load(WAIVERS.read_text(encoding="utf-8")) or {}
        for row in doc.get("waivers", []):
            cid = row.get("claim_id")
            expiry = row.get("expires_at")
            if not cid or not expiry:
                continue
            try:
                exp_date = date.fromisoformat(str(expiry))
            except ValueError:
                continue
            if exp_date >= today:
                waiver_map[cid] = row

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

    unwaived_empirical = []
    for e in incomplete:
        if e.get("type") != "empirical":
            continue
        claim_id = e.get("claim_id")
        if claim_id not in waiver_map:
            unwaived_empirical.append(claim_id)
    if unwaived_empirical:
        print(
            "strict audit gate failed: empirical claims incomplete without active waiver: "
            + ", ".join(sorted(unwaived_empirical)),
            file=sys.stderr,
        )
        return 1

    print("strict audit gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
