#!/usr/bin/env python3
import json
import sys
from pathlib import Path

import yaml
from jsonschema import validate

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "skills/references/orchestration-contract.yaml"
SCHEMA = ROOT / "skills/references/orchestration-contract.schema.json"


def main() -> int:
    if not CONTRACT.exists() or not SCHEMA.exists():
        print("missing orchestration contract", file=sys.stderr)
        return 1

    doc = yaml.safe_load(CONTRACT.read_text(encoding="utf-8")) or {}
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    validate(instance=doc, schema=schema)

    execution = doc.get("execution_order", [])
    if not execution:
        print("execution_order is empty", file=sys.stderr)
        return 1

    for idx, item in enumerate(execution, start=1):
        if "role" not in item:
            print(f"execution_order[{idx}] missing role", file=sys.stderr)
            return 1
        for out in item.get("outputs", []):
            p = ROOT / out
            if not p.exists():
                print(f"missing required output: {out}", file=sys.stderr)
                return 1

        for s in item.get("schemas", []):
            p = ROOT / s
            if not p.exists():
                print(f"missing schema file: {s}", file=sys.stderr)
                return 1

    print(f"orchestration contract validation passed ({len(execution)} stages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
