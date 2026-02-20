#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from jsonschema import validate

ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "compliance/mappings/eu_ai_act_sox_matrix.json"
SCHEMA = ROOT / "compliance/mappings/control_matrix.schema.json"
BENCH_SCHEMA = ROOT / "benchmarks/reports/benchmark_run.schema.json"
FAULT_SCHEMA = ROOT / "fault/reports/fault_campaign.schema.json"
BENCH_FILES = [
    ROOT / "benchmarks/raw/durable-governed-path.json",
    ROOT / "benchmarks/raw/non-durable-fast-path.json",
    ROOT / "benchmarks/raw/finops-sensitivity-sweep.json",
]
FAULT_FILES = [
    ROOT / "fault/raw/revocation_delay.json",
    ROOT / "fault/raw/version_skew.json",
    ROOT / "fault/raw/stale_replay.json",
    ROOT / "fault/raw/clock_skew.json",
]


def is_placeholder_text(path: Path) -> bool:
    if not path.exists():
        return True
    txt = path.read_text(encoding="utf-8", errors="ignore").lower()
    placeholder_markers = [
        "bootstrap placeholder",
        "status: bootstrap",
        "pending",
        "todo",
    ]
    return any(m in txt for m in placeholder_markers)


def main():
    if not MATRIX.exists() or not SCHEMA.exists() or not BENCH_SCHEMA.exists() or not FAULT_SCHEMA.exists():
        print("missing compliance matrix or schema", file=sys.stderr)
        return 1

    matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    bench_schema = json.loads(BENCH_SCHEMA.read_text(encoding="utf-8"))
    fault_schema = json.loads(FAULT_SCHEMA.read_text(encoding="utf-8"))
    validate(instance=matrix, schema=schema)

    failures = []
    for row in matrix:
        artifact = ROOT / row["evidence_artifact"]
        result = row["result"]
        if result in {"pass", "fail"} and not artifact.exists():
            failures.append(
                f"{row['control_id']}: result={result} but evidence artifact missing: {row['evidence_artifact']}"
            )
        if result in {"pass", "fail"} and is_placeholder_text(artifact):
            failures.append(
                f"{row['control_id']}: result={result} but artifact appears to be placeholder text: {row['evidence_artifact']}"
            )

    for bfile in BENCH_FILES:
        if not bfile.exists():
            failures.append(f"benchmark evidence missing: {bfile.relative_to(ROOT)}")
            continue
        payload = json.loads(bfile.read_text(encoding="utf-8"))
        validate(instance=payload, schema=bench_schema)
        if payload.get("data_source") != "real":
            failures.append(f"benchmark run must be real data: {bfile.relative_to(ROOT)}")
        if payload.get("runner") not in {"ghz", "k6", "hybrid"}:
            failures.append(f"benchmark runner missing/invalid: {bfile.relative_to(ROOT)}")

    for ffile in FAULT_FILES:
        if not ffile.exists():
            failures.append(f"fault evidence missing: {ffile.relative_to(ROOT)}")
            continue
        payload = json.loads(ffile.read_text(encoding="utf-8"))
        validate(instance=payload, schema=fault_schema)
        if payload.get("data_source") != "real":
            failures.append(f"fault run must be real data: {ffile.relative_to(ROOT)}")
        if payload.get("evidence_class") != "measured":
            failures.append(f"fault run must be measured evidence: {ffile.relative_to(ROOT)}")
        mode = (
            payload.get("metadata", {}).get("mode", "").lower()
            if isinstance(payload.get("metadata"), dict)
            else ""
        )
        if "simulated" in mode:
            failures.append(f"fault run contains simulated mode marker: {ffile.relative_to(ROOT)}")

    if failures:
        print("evidence gate failed:")
        for f in failures:
            print(" -", f)
        return 1

    print("evidence gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
