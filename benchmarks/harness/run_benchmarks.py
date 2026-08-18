#!/usr/bin/env python3
import argparse
import copy
import json
import math
import os
import platform
import statistics
import subprocess
import tempfile
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_MANIFEST = ROOT / "contracts/snapshots/version_manifest.yaml"


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    vals = sorted(values)
    k = max(0, min(len(vals) - 1, int(math.ceil((p / 100.0) * len(vals)) - 1)))
    return float(vals[k])


def ci95(values: list[float]) -> dict[str, float]:
    if len(values) < 2:
        x = values[0] if values else 0.0
        return {"low": float(x), "high": float(x)}
    mean = statistics.mean(values)
    stdev = statistics.pstdev(values)
    margin = 1.96 * (stdev / math.sqrt(len(values)))
    return {"low": float(mean - margin), "high": float(mean + margin)}


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, check=True, text=True, capture_output=True)


def resolve_source_repo(value: str | None) -> Path:
    raw = os.environ.get("FULCRUM_SOURCE_REPO") or value
    if not raw or not raw.strip():
        raise SystemExit(
            "BENCH_SOURCE_REPO_UNCONFIGURED: configure FULCRUM_SOURCE_REPO or "
            "manifest source_repo before a live benchmark run"
        )
    candidate = Path(raw).expanduser()
    if candidate.is_absolute():
        return candidate
    return (ROOT / candidate).resolve()


def load_credentials(creds_file: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not creds_file.exists():
        return out

    for line in creds_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line.startswith("export "):
            continue
        keyval = line[len("export ") :]
        if "=" not in keyval:
            continue
        key, val = keyval.split("=", 1)
        out[key.strip()] = val.strip().strip("'").strip('"')
    return out


def ensure_credentials(source_repo: Path, creds_file: Path) -> dict[str, str]:
    creds = load_credentials(creds_file)
    if creds.get("FULCRUM_TEST_API_KEY") and creds.get("FULCRUM_TEST_TENANT_ID"):
        return creds

    setup_script = source_repo / "scripts/setup-load-test-auth.sh"
    if not setup_script.exists():
        raise RuntimeError(
            f"missing credentials and setup script not found: {setup_script}"
        )

    run([str(setup_script)], cwd=source_repo)
    creds = load_credentials(creds_file)
    if not creds.get("FULCRUM_TEST_API_KEY") or not creds.get("FULCRUM_TEST_TENANT_ID"):
        raise RuntimeError(f"unable to load credentials from {creds_file}")
    return creds


def deep_replace(value: Any, replacements: dict[str, str]) -> Any:
    if isinstance(value, dict):
        return {k: deep_replace(v, replacements) for k, v in value.items()}
    if isinstance(value, list):
        return [deep_replace(v, replacements) for v in value]
    if isinstance(value, str):
        out = value
        for token, repl in replacements.items():
            out = out.replace(token, repl)
        return out
    return value


def parse_ghz_latency_ms(payload: dict[str, Any]) -> tuple[list[float], int]:
    details = payload.get("details", []) or []
    status_dist = payload.get("statusCodeDistribution", {}) or {}
    errors = int(sum(v for k, v in status_dist.items() if k != "OK"))

    latencies_ok = []
    latencies_all = []
    for d in details:
        ns = d.get("latency")
        if ns is None:
            continue
        ms = float(ns) / 1_000_000.0
        latencies_all.append(ms)
        if d.get("status") == "OK":
            latencies_ok.append(ms)

    if latencies_ok:
        return latencies_ok, errors
    return latencies_all, errors


def hardware_profile() -> dict[str, Any]:
    return {
        "platform": platform.platform(),
        "arch": platform.machine(),
        "cpu_count": os.cpu_count() or 1,
    }


def contracts_snapshot_sha() -> str:
    if not CONTRACT_MANIFEST.exists():
        return "unknown"
    doc = yaml.safe_load(CONTRACT_MANIFEST.read_text(encoding="utf-8")) or {}
    return str(doc.get("source_commit_sha", "unknown"))


def run_ghz_once(
    host: str,
    method: str,
    request_obj: dict[str, Any],
    api_key: str,
    total: int,
    concurrency: int,
    rps: int,
    timeout_ms: int,
    output_path: Path,
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
        host,
    ]
    try:
        proc = run(cmd)
        payload = json.loads(proc.stdout)
    finally:
        req_path.unlink(missing_ok=True)
        md_path.unlink(missing_ok=True)

    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return payload


def benchmark_workload(
    workload: dict[str, Any],
    manifest: dict[str, Any],
    out_dir: Path,
    commit: str,
    env: str,
    run_prefix: str,
    source_repo: Path,
) -> dict[str, Any]:
    if workload.get("runner") != "ghz":
        raise RuntimeError(f"unsupported runner: {workload.get('runner')}")

    creds_file = Path(manifest.get("credentials_file", "/tmp/fulcrum-load-test-credentials.sh"))
    creds = ensure_credentials(source_repo, creds_file)
    api_key = creds["FULCRUM_TEST_API_KEY"]
    tenant_id = creds["FULCRUM_TEST_TENANT_ID"]

    host = manifest.get("host", "localhost:50051")
    repeats = int(manifest.get("repeats", 1))
    method = workload["method"]
    total = int(workload.get("total", 20))
    concurrency = int(workload.get("concurrency", 1))
    rps = int(workload.get("rps", 2))
    timeout_ms = int(workload.get("timeout_ms", 20_000))

    all_latencies: list[float] = []
    errors = 0
    sensitivity_details = []
    ts = int(time.time())
    run_id = f"{run_prefix}-{workload['name']}-{ts}"

    for repeat in range(1, repeats + 1):
        request_template = copy.deepcopy(workload["request"])
        replacements = {
            "${TENANT_ID}": tenant_id,
            "${RUN_ID}": f"{run_id}-r{repeat}-{uuid.uuid4().hex[:8]}",
            "${TIMESTAMP}": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        request_obj = deep_replace(request_template, replacements)
        raw_out = out_dir / f"raw-{run_id}-repeat-{repeat}.json"
        payload = run_ghz_once(
            host=host,
            method=method,
            request_obj=request_obj,
            api_key=api_key,
            total=total,
            concurrency=concurrency,
            rps=rps,
            timeout_ms=timeout_ms,
            output_path=raw_out,
        )
        lat_ms, err_count = parse_ghz_latency_ms(payload)
        all_latencies.extend(lat_ms)
        errors += err_count

        for profile in workload.get("sensitivity_profiles", []):
            profile_name = profile["name"]
            p_total = int(profile.get("total", total))
            p_rps = int(profile.get("rps", rps))
            p_timeout = int(profile.get("timeout_ms", timeout_ms))
            req_profile = copy.deepcopy(request_obj)
            attrs = (
                req_profile.setdefault("context", {})
                .setdefault("attributes", {})
            )
            attrs["token_class"] = profile_name
            raw_profile = out_dir / f"raw-{run_id}-{profile_name}-repeat-{repeat}.json"
            p_payload = run_ghz_once(
                host=host,
                method=method,
                request_obj=req_profile,
                api_key=api_key,
                total=p_total,
                concurrency=concurrency,
                rps=p_rps,
                timeout_ms=p_timeout,
                output_path=raw_profile,
            )
            p_lat_ms, p_err = parse_ghz_latency_ms(p_payload)
            sensitivity_details.append(
                {
                    "profile": profile_name,
                    "repeat": repeat,
                    "rps": p_rps,
                    "timeout_ms": p_timeout,
                    "estimated_unit_cost_usd": float(profile.get("estimated_unit_cost_usd", 0.0)),
                    "samples": len(p_lat_ms),
                    "errors": p_err,
                    "p50": percentile(p_lat_ms, 50),
                    "p95": percentile(p_lat_ms, 95),
                    "p99": percentile(p_lat_ms, 99),
                    "ci95": ci95(p_lat_ms),
                }
            )

    if not all_latencies:
        raise RuntimeError(f"no latency samples collected for workload {workload['name']}")

    if sensitivity_details:
        detail_path = out_dir / f"raw-{run_id}-sensitivity-details.json"
        detail_path.write_text(
            json.dumps(
                {
                    "workload": workload["name"],
                    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "details": sensitivity_details,
                },
                indent=2,
            ),
            encoding="utf-8",
        )

    return {
        "run_id": run_id,
        "data_source": "real",
        "runner": "ghz",
        "hardware_profile": hardware_profile(),
        "fulcrum_commit": run(["git", "-C", str(source_repo), "rev-parse", "HEAD"]).stdout.strip(),
        "contracts_snapshot_sha": contracts_snapshot_sha(),
        "commit": commit,
        "env": env,
        "workload": workload["name"],
        "durability_mode": workload["durability_mode"],
        "samples": len(all_latencies),
        "p50": percentile(all_latencies, 50),
        "p95": percentile(all_latencies, 95),
        "p99": percentile(all_latencies, 99),
        "ci95": ci95(all_latencies),
        "errors": errors,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--workload", default=None)
    parser.add_argument("--commit", default=None)
    parser.add_argument("--env", default=None)
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    workloads = manifest.get("workloads", [])
    if args.workload:
        workloads = [w for w in workloads if w.get("name") == args.workload]
        if not workloads:
            raise SystemExit(f"workload not found: {args.workload}")

    commit = args.commit if args.commit else manifest.get("commit", "unknown")
    env = args.env if args.env else manifest.get("env", "local")
    run_prefix = manifest.get("run_id_prefix", "bench")
    source_repo = resolve_source_repo(manifest.get("source_repo"))
    if not source_repo.exists():
        raise SystemExit(
            f"source repo not found: {source_repo} "
            "(set FULCRUM_SOURCE_REPO or update manifest source_repo)"
        )
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    reports = []
    for workload in workloads:
        reports.append(
            benchmark_workload(
                workload=workload,
                manifest=manifest,
                out_dir=out_path.parent,
                commit=commit,
                env=env,
                run_prefix=run_prefix,
                source_repo=source_repo,
            )
        )

    if len(reports) == 1:
        out_path.write_text(json.dumps(reports[0], indent=2), encoding="utf-8")
    else:
        summary = {
            "run_count": len(reports),
            "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "manifest": str(manifest_path),
        }
        out_path.write_text(
            json.dumps({"summary": summary, "runs": reports}, indent=2),
            encoding="utf-8",
        )

    for r in reports:
        (out_path.parent / f"{r['run_id']}.json").write_text(
            json.dumps(r, indent=2), encoding="utf-8"
        )


if __name__ == "__main__":
    main()
