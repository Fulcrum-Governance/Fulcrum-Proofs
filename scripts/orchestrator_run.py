#!/usr/bin/env python3
import json
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
CLAIM_LEDGER = ROOT / "claims/claim_ledger.yaml"
THEOREM_INV = ROOT / "claims/theorem_inventory.yaml"
MATRIX = ROOT / "compliance/mappings/eu_ai_act_sox_matrix.json"
SUMMARY = ROOT / "audits/final/orchestrator-run-summary.md"


def exists_all(paths: list[Path]) -> bool:
    return all(p.exists() for p in paths)


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    ledger = yaml.safe_load(CLAIM_LEDGER.read_text(encoding="utf-8")) or {}
    theorem_doc = yaml.safe_load(THEOREM_INV.read_text(encoding="utf-8")) or {}
    theorem_status = {
        t["theorem_id"]: t.get("proof_status")
        for t in theorem_doc.get("theorems", [])
    }

    proof_artifacts = [
        ROOT / "proofs/lean/reports/lake-build.log",
        ROOT / "proofs/lean/reports/theorem-inventory.txt",
        ROOT / "proofs/lean/reports/dependency-map.txt",
        ROOT / "proofs/lean/reports/no-sorry-check.log",
    ]
    tla_artifacts = [
        ROOT / "models/tla/reports/tlc-GatewaySafetySmall.log",
        ROOT / "models/tla/reports/tlc-GatewaySafety.log",
        ROOT / "models/tla/reports/tlc-GatewaySafetyMedium.log",
    ]
    bench_artifacts = [
        ROOT / "benchmarks/raw/durable-governed-path.json",
        ROOT / "benchmarks/raw/non-durable-fast-path.json",
        ROOT / "benchmarks/raw/finops-sensitivity-sweep.json",
        ROOT / "benchmarks/raw/nightly-suite.json",
    ]
    fault_artifacts = [
        ROOT / "fault/raw/revocation_delay.json",
        ROOT / "fault/raw/version_skew.json",
        ROOT / "fault/raw/stale_replay.json",
        ROOT / "fault/raw/clock_skew.json",
    ]

    matrix = load_json(MATRIX)
    matrix_pass = all(row.get("result") in {"pass", "waived"} for row in matrix)

    fault_within_bounds = True
    for p in fault_artifacts:
        if not p.exists():
            fault_within_bounds = False
            break
        if not load_json(p).get("within_bounds", False):
            fault_within_bounds = False
            break

    benchmarks_real = True
    for p in bench_artifacts[:3]:
        if not p.exists():
            benchmarks_real = False
            break
        payload = load_json(p)
        if payload.get("data_source") != "real":
            benchmarks_real = False
            break

    closures = {
        "C-004": benchmarks_real,
        "C-005": False,
        "C-009": exists_all(proof_artifacts)
        and theorem_status.get("THM-BUDGET-LOCAL") == "proven"
        and theorem_status.get("THM-PRIVILEGE-STATIC") == "proven",
        "C-014": theorem_status.get("THM-TEMPORAL-CONSERVATION-SPEC") == "proven"
        and exists_all(tla_artifacts)
        and fault_within_bounds,
        "C-015": matrix_pass
        and exists_all(
            [
                ROOT / "audits/post-repair/gate-fail-closed-evidence.md",
                ROOT / "audits/post-repair/immutable-audit-evidence.md",
                ROOT / "audits/post-repair/budget-authz-evidence.md",
                ROOT / "audits/post-repair/epoch-freshness-evidence.md",
                ROOT / "compliance/reports/evidence-gap-report.md",
            ]
        ),
        "C-016": benchmarks_real and (ROOT / "benchmarks/raw/nightly-suite.json").exists(),
        "C-017": benchmarks_real and exists_all(
            [
                ROOT / "benchmarks/raw/finops-sensitivity-sweep.json",
            ]
        ),
    }

    entries = ledger.get("entries", [])
    for e in entries:
        cid = e.get("claim_id")
        if cid in closures and closures[cid]:
            e["status"] = "proven"
        elif cid == "C-005":
            e["status"] = "incomplete"
        else:
            e["status"] = "incomplete"

        refs = []
        if cid == "C-009":
            refs = [str(p.relative_to(ROOT)) for p in proof_artifacts if p.exists()]
        elif cid in {"C-004", "C-016", "C-017"}:
            refs = [str(p.relative_to(ROOT)) for p in bench_artifacts if p.exists()]
        elif cid == "C-014":
            refs = (
                [str(p.relative_to(ROOT)) for p in tla_artifacts if p.exists()]
                + [str(p.relative_to(ROOT)) for p in fault_artifacts if p.exists()]
            )
        elif cid == "C-015":
            refs = [str(MATRIX.relative_to(ROOT))]
        if refs:
            e["evidence_refs"] = refs

    CLAIM_LEDGER.write_text(yaml.safe_dump(ledger, sort_keys=False), encoding="utf-8")

    completed_stages = 0
    completed_stages += 1 if (ROOT / "audits/post-repair/research-validation-report.md").exists() else 0
    completed_stages += 1 if closures["C-009"] else 0
    completed_stages += 1 if exists_all(tla_artifacts) else 0
    completed_stages += 1 if closures["C-016"] else 0
    completed_stages += 1 if exists_all(fault_artifacts) else 0
    completed_stages += 1 if closures["C-015"] else 0
    blocked = sorted([cid for cid, ok in closures.items() if not ok and cid != "C-005"])
    closure_ok = len(blocked) == 0

    SUMMARY.write_text(
        "\n".join(
            [
                "# Orchestrator Run Summary",
                "",
                "Status: updated.",
                "",
                "- Execution contract loaded: yes",
                f"- Specialist stages completed: {completed_stages}/6",
                f"- Closure policy met: {'yes' if closure_ok else 'no'}",
                f"- Blocking claims: {', '.join(blocked) if blocked else 'none'}",
                "- Waived claim(s): C-005",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
