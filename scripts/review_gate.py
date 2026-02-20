#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from jsonschema import validate


ROOT = Path(__file__).resolve().parents[1]
FINDINGS_PATH = ROOT / "audits/final/re-audit-findings.json"
SCHEMA_PATH = ROOT / "audits/final/re-audit.schema.json"


def main() -> int:
    if not FINDINGS_PATH.exists():
        print(f"missing findings file: {FINDINGS_PATH}", file=sys.stderr)
        return 1
    if not SCHEMA_PATH.exists():
        print(f"missing findings schema: {SCHEMA_PATH}", file=sys.stderr)
        return 1

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    findings = json.loads(FINDINGS_PATH.read_text(encoding="utf-8"))
    if not isinstance(findings, list):
        print("findings payload must be a JSON array", file=sys.stderr)
        return 1

    critical_open = []
    high_open = []
    for row in findings:
        validate(instance=row, schema=schema)
        severity = row.get("severity")
        status = row.get("status")
        if status in {"open", "partially_fixed"}:
            if severity == "Critical":
                critical_open.append(row.get("finding_id", "unknown"))
            if severity == "High":
                high_open.append(row.get("finding_id", "unknown"))

    print(
        "review findings: "
        f"total={len(findings)} critical_open={len(critical_open)} high_open={len(high_open)}"
    )

    if critical_open or high_open:
        if critical_open:
            print("open critical findings: " + ", ".join(critical_open), file=sys.stderr)
        if high_open:
            print("open high findings: " + ", ".join(high_open), file=sys.stderr)
        return 1

    print("review gate passed: no open Critical/High findings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
