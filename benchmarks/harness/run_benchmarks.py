#!/usr/bin/env python3
import argparse
import json
import math
import random
import statistics
import time
from pathlib import Path

import yaml


def percentile(values, p):
    if not values:
        return 0.0
    vals = sorted(values)
    k = max(0, min(len(vals) - 1, int(math.ceil((p / 100.0) * len(vals)) - 1)))
    return float(vals[k])


def ci95(values):
    if len(values) < 2:
        x = values[0] if values else 0.0
        return {"low": float(x), "high": float(x)}
    mean = statistics.mean(values)
    stdev = statistics.pstdev(values)
    margin = 1.96 * (stdev / math.sqrt(len(values)))
    return {"low": float(mean - margin), "high": float(mean + margin)}


def simulate_latency(samples, mean_ms, stddev_ms):
    out = []
    for _ in range(samples):
        v = random.gauss(mean_ms, stddev_ms)
        out.append(max(0.01, v))
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--workload", default=None)
    parser.add_argument("--commit", default=None)
    parser.add_argument("--env", default=None)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    random.seed(args.seed)
    manifest = yaml.safe_load(Path(args.manifest).read_text(encoding="utf-8"))

    workloads = manifest.get("workloads", [])
    if args.workload:
        workloads = [w for w in workloads if w.get("name") == args.workload]
        if not workloads:
            raise SystemExit(f"workload not found: {args.workload}")

    commit = args.commit if args.commit else manifest.get("commit", "unknown")
    env = args.env if args.env else manifest.get("env", "local")
    run_prefix = manifest.get("run_id_prefix", "bench")

    reports = []
    timestamp = int(time.time())
    for idx, w in enumerate(workloads, start=1):
        samples = int(w.get("samples", 1000))
        latency = simulate_latency(samples, float(w.get("mean_ms", 1.0)), float(w.get("stddev_ms", 0.2)))
        errors = int(samples * float(w.get("error_rate", 0.0)))
        report = {
            "run_id": f"{run_prefix}-{timestamp}-{idx}",
            "commit": commit,
            "env": env,
            "workload": w["name"],
            "durability_mode": w["durability_mode"],
            "samples": samples,
            "p50": percentile(latency, 50),
            "p95": percentile(latency, 95),
            "p99": percentile(latency, 99),
            "ci95": ci95(latency),
            "errors": errors,
        }
        reports.append(report)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if len(reports) == 1:
        out_path.write_text(json.dumps(reports[0], indent=2), encoding="utf-8")
    else:
        summary = {
            "run_count": len(reports),
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "manifest": str(Path(args.manifest)),
        }
        out_path.write_text(json.dumps({"summary": summary, "runs": reports}, indent=2), encoding="utf-8")

    # Also emit individual run files for evidence indexing
    report_dir = out_path.parent
    for r in reports:
        (report_dir / f"{r['run_id']}.json").write_text(json.dumps(r, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
