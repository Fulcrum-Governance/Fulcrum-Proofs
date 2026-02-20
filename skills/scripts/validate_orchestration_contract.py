#!/usr/bin/env python3
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "skills/references/orchestration-contract.yaml"


def main() -> int:
    if not CONTRACT.exists():
        print("missing orchestration contract", file=sys.stderr)
        return 1

    doc = yaml.safe_load(CONTRACT.read_text(encoding="utf-8")) or {}
    required_top = ["version", "program", "execution_order", "closure_policy"]
    missing = [k for k in required_top if k not in doc]
    if missing:
        print(f"orchestration contract missing keys: {', '.join(missing)}", file=sys.stderr)
        return 1

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

    print(f"orchestration contract validation passed ({len(execution)} stages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
