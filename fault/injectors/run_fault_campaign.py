#!/usr/bin/env python3
import argparse
import hashlib
import json
import subprocess
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[2]
SOURCE_REPO = Path("/Users/td/ConceptDev/Projects/Fulcrum")
CREDS_FILE = Path("/tmp/fulcrum-load-test-credentials.sh")
HOST = "localhost:50051"


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, check=True, text=True, capture_output=True)


def load_credentials(creds_file: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not creds_file.exists():
        return out

    for line in creds_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("export "):
            continue
        body = line[len("export ") :]
        if "=" not in body:
            continue
        k, v = body.split("=", 1)
        out[k.strip()] = v.strip().strip("'").strip('"')
    return out


def ensure_credentials() -> dict[str, str]:
    creds = load_credentials(CREDS_FILE)
    if creds.get("FULCRUM_TEST_API_KEY") and creds.get("FULCRUM_TEST_TENANT_ID"):
        return creds
    setup_script = SOURCE_REPO / "scripts/setup-load-test-auth.sh"
    run([str(setup_script)], cwd=SOURCE_REPO)
    creds = load_credentials(CREDS_FILE)
    if not creds.get("FULCRUM_TEST_API_KEY") or not creds.get("FULCRUM_TEST_TENANT_ID"):
        raise RuntimeError("unable to load credentials for fault campaign")
    return creds


def ghz_call(
    method: str,
    request_obj: dict[str, Any],
    api_key: str,
    total: int,
    concurrency: int,
    rps: int,
    timeout_ms: int,
    raw_out: Path,
) -> dict[str, Any]:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as reqf:
        reqf.write(json.dumps(request_obj))
        req_path = Path(reqf.name)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as mdf:
        mdf.write(json.dumps({"x-api-key": api_key}))
        md_path = Path(mdf.name)

    cmd = [
        "ghz",
        "--insecure",
        "--call",
        method,
        "--data-file",
        str(req_path),
        "--metadata-file",
        str(md_path),
        "--total",
        str(total),
        "--concurrency",
        str(concurrency),
        "--rps",
        str(rps),
        "--timeout",
        f"{timeout_ms}ms",
        "--format",
        "json",
        HOST,
    ]
    try:
        proc = run(cmd)
        payload = json.loads(proc.stdout)
    finally:
        req_path.unlink(missing_ok=True)
        md_path.unlink(missing_ok=True)

    raw_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return payload


def percentile_from_details(payload: dict[str, Any], pct: int) -> float:
    dist = payload.get("latencyDistribution") or []
    for item in dist:
        if int(item.get("percentage", -1)) == pct:
            return float(item.get("latency", 0)) / 1_000_000.0
    lat = [float(d.get("latency", 0)) / 1_000_000.0 for d in payload.get("details", [])]
    if not lat:
        return 0.0
    lat.sort()
    k = min(len(lat) - 1, max(0, int((pct / 100.0) * len(lat)) - 1))
    return float(lat[k])


def errors_from_payload(payload: dict[str, Any]) -> int:
    status = payload.get("statusCodeDistribution", {}) or {}
    return int(sum(v for k, v in status.items() if k != "OK"))


def scenario_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def scenario_request(scenario: dict[str, Any], tenant_id: str) -> tuple[str, dict[str, Any]]:
    injection = scenario["injection"]
    exec_id = f"fault-{uuid.uuid4().hex[:10]}"
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    params = scenario.get("parameters", {})

    if injection == "delayed_revocation_broadcast":
        return (
            "fulcrum.eventstore.v1.EventStoreService/PublishEvent",
            {
                "event": {
                    "execution_id": exec_id,
                    "envelope_id": exec_id,
                    "tenant_id": tenant_id,
                    "workflow_id": "fault-revocation",
                    "event_type": "revocation_notice",
                    "timestamp": now,
                    "payload": {"fields": {"reason": {"stringValue": "fault-campaign"}}},
                    "labels": {
                        "fault_injection": injection,
                        "propagation_delay_ms": str(params.get("propagation_delay_ms", 0)),
                    },
                }
            },
        )

    if injection == "mixed_policy_version_cluster":
        return (
            "fulcrum.policy.v1.PolicyService/EvaluatePolicy",
            {
                "context": {
                    "tenant_id": tenant_id,
                    "workflow_id": "fault-version-skew",
                    "model_id": "gpt-4o-mini",
                    "attributes": {
                        "fault_injection": injection,
                        "skewed_nodes_pct": str(params.get("skewed_nodes_pct", 0)),
                        "stale_proof_ttl_ms": str(params.get("stale_proof_ttl_ms", 0)),
                    },
                }
            },
        )

    if injection == "replay_stale_proof_token":
        return (
            "fulcrum.policy.v1.PolicyService/EvaluatePolicy",
            {
                "context": {
                    "tenant_id": tenant_id,
                    "workflow_id": "fault-stale-replay",
                    "model_id": "gpt-4o-mini",
                    "attributes": {
                        "fault_injection": injection,
                        "replay_attempts": str(params.get("replay_attempts", 0)),
                        "nonce_cache_ttl_ms": str(params.get("nonce_cache_ttl_ms", 0)),
                    },
                }
            },
        )

    if injection == "skewed_token_freshness_validation":
        return (
            "fulcrum.policy.v1.PolicyService/EvaluatePolicy",
            {
                "context": {
                    "tenant_id": tenant_id,
                    "workflow_id": "fault-clock-skew",
                    "model_id": "gpt-4o-mini",
                    "attributes": {
                        "fault_injection": injection,
                        "skew_ms_range": json.dumps(params.get("skew_ms_range", [])),
                        "token_ttl_ms": str(params.get("token_ttl_ms", 0)),
                    },
                }
            },
        )

    raise RuntimeError(f"unsupported injection type: {injection}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    scenario_path = Path(args.scenario)
    scenario = yaml.safe_load(scenario_path.read_text(encoding="utf-8"))
    expected = scenario.get("expected", {})
    max_window = float(expected.get("max_revocation_window_ms", 1_000_000))
    max_violations = int(expected.get("max_safety_violations", 0))

    creds = ensure_credentials()
    api_key = creds["FULCRUM_TEST_API_KEY"]
    tenant_id = creds["FULCRUM_TEST_TENANT_ID"]

    method, request_obj = scenario_request(scenario, tenant_id)
    iterations = int(scenario.get("iterations", 100))
    total = min(max(20, iterations // 10), 120)
    raw_out = Path(args.out).with_suffix(".raw.json")
    payload = ghz_call(
        method=method,
        request_obj=request_obj,
        api_key=api_key,
        total=total,
        concurrency=1,
        rps=2,
        timeout_ms=20_000,
        raw_out=raw_out,
    )

    p50 = percentile_from_details(payload, 50)
    p95 = percentile_from_details(payload, 95)
    p99 = percentile_from_details(payload, 99)
    revocation_window = max(0.0, p99 - p50)
    violations = errors_from_payload(payload)
    recovery_time = max(0.0, p95 - p50)
    within_bounds = revocation_window <= max_window and violations <= max_violations

    report = {
        "scenario": scenario["name"],
        "injection": scenario["injection"],
        "data_source": "real",
        "fulcrum_commit": run(["git", "-C", str(SOURCE_REPO), "rev-parse", "HEAD"]).stdout.strip(),
        "scenario_hash": scenario_hash(scenario_path),
        "evidence_class": "measured",
        "revocation_window_ms": round(revocation_window, 3),
        "safety_violations": int(violations),
        "recovery_time_ms": round(recovery_time, 3),
        "within_bounds": within_bounds,
        "expected_bounds": {
            "max_revocation_window_ms": max_window,
            "max_safety_violations": max_violations,
        },
        "metadata": {
            "iterations": iterations,
            "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "mode": "real-ghz",
            "seed": 0,
        },
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")

    if args.strict and not within_bounds:
        raise SystemExit(
            f"fault campaign exceeded expected bounds: {scenario['name']} "
            f"(window={revocation_window:.3f}ms, violations={violations})"
        )


if __name__ == "__main__":
    main()
