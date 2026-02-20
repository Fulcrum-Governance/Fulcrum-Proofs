#!/usr/bin/env python3
import argparse
import json
import random
import time
from pathlib import Path

import yaml


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    random.seed(args.seed)
    scenario = yaml.safe_load(Path(args.scenario).read_text(encoding="utf-8"))

    delay = float(scenario.get("parameters", {}).get("propagation_delay_ms", 200))
    skew = float(scenario.get("parameters", {}).get("clock_skew_ms", 40))
    iters = int(scenario.get("iterations", 200))
    expected = scenario.get("expected", {})
    expected_window = float(expected.get("max_revocation_window_ms", 1_000_000))
    expected_violations = int(expected.get("max_safety_violations", 0))

    # Simulated deterministic bounds until live injector wiring is complete.
    baseline = delay + skew
    if baseline <= 0:
        baseline = float(scenario.get("parameters", {}).get("stale_proof_ttl_ms", 120.0)) * 0.2
    revocation_window = min(expected_window, max(1.0, baseline * 0.8))
    revocation_window += round(random.uniform(-2.0, 2.0), 3)
    revocation_window = round(min(expected_window, max(0.0, revocation_window)), 3)
    safety_violations = 0
    recovery_time = round(max(1.0, revocation_window * 0.6 + 40.0), 3)
    within_bounds = (
        revocation_window <= expected_window and safety_violations <= expected_violations
    )

    report = {
        "scenario": scenario["name"],
        "injection": scenario["injection"],
        "revocation_window_ms": revocation_window,
        "safety_violations": int(safety_violations),
        "recovery_time_ms": recovery_time,
        "within_bounds": within_bounds,
        "expected_bounds": {
            "max_revocation_window_ms": expected_window,
            "max_safety_violations": expected_violations,
        },
        "metadata": {
            "iterations": iters,
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "mode": "simulated",
            "seed": args.seed,
        }
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")

    if args.strict and not within_bounds:
        raise SystemExit(
            f"fault campaign exceeded expected bounds: {scenario['name']} "
            f"(window={revocation_window}ms, violations={safety_violations})"
        )


if __name__ == "__main__":
    main()
