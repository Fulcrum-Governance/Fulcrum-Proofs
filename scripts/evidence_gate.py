#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from jsonschema import validate

ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "compliance/mappings/eu_ai_act_sox_matrix.json"
SCHEMA = ROOT / "compliance/mappings/control_matrix.schema.json"


def main():
    if not MATRIX.exists() or not SCHEMA.exists():
        print("missing compliance matrix or schema", file=sys.stderr)
        return 1

    matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    validate(instance=matrix, schema=schema)

    failures = []
    for row in matrix:
        artifact = ROOT / row["evidence_artifact"]
        result = row["result"]
        if result in {"pass", "fail"} and not artifact.exists():
            failures.append(
                f"{row['control_id']}: result={result} but evidence artifact missing: {row['evidence_artifact']}"
            )

    if failures:
        print("evidence gate failed:")
        for f in failures:
            print(" -", f)
        return 1

    print("evidence gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
