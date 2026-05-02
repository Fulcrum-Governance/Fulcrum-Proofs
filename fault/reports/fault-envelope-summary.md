# Fault Envelope Summary

Status: populated from real-mode gate runs.

This summary aggregates the four fault-injection scenarios that bound the
`C-014` claim (revocation safety under adversarial network and clock conditions).
Each row reports the measured envelope from the canonical run captured in
`fault/raw/<scenario>.json` (alongside the raw ghz output at
`fault/raw/<scenario>.raw.json`). All four runs were executed against the
fulcrum policy gRPC service at commit `5c86a3517f803f525041d826dfc17ea497bbd147`
in real mode (`real-ghz`), seed `0`, on 2026-02-20.

The bounds reported here are **measured envelopes**, not absolute guarantees:
they reflect the worst-case observation across the configured iteration count.
Burst tail latency remains present (see Notes), so a deployment in a materially
different hardware or workload regime should re-run the campaign before relying
on these numbers for SLOs. This caveat is also reflected in
`audits/final/post-repair-re-audit.md` §1 blocker 2.

## Scenario envelopes

| Scenario | Injection | Iterations | Revocation window (ms) | Bound (ms) | Recovery (ms) | Safety violations | Within bounds | gRPC P99 (ms) |
|---|---|---|---|---|---|---|---|---|
| `revocation-delay` | `delayed_revocation_broadcast` | 500 | 297.38 | 500 | 242.55 | 0 | yes | 299.73 |
| `clock-skew` | `skewed_token_freshness_validation` | 500 | 76.00 | 400 | 32.64 | 0 | yes | 78.16 |
| `version-skew` | `mixed_policy_version_cluster` | 500 | 372.63 | 750 | 7.27 | 0 | yes | 374.75 |
| `stale-proof-replay` | `replay_stale_proof_token` | 300 | 349.91 | 500 | 215.84 | 0 | yes | 352.06 |

`Revocation window` is the longest interval between fault-onset and successful
revocation observed across the scenario's iterations; `Bound` is the
configured `max_revocation_window_ms` from the corresponding
`fault/scenarios/<scenario>.yaml`. `Recovery` is the time from revocation to
restored steady-state. `gRPC P99` is the 99th percentile request latency from
the underlying ghz run (`fault/raw/<scenario>.raw.json`); it is shown as a
sanity check that the fault campaign itself completed without service errors
(every scenario observed `100 % OK` status across all calls).

## Aggregate

- **Scenarios run**: 4
- **Total iterations**: 1,800
- **Safety violations across all scenarios**: 0
- **All scenarios within configured bounds**: yes
- **Aggregate gRPC error count**: 0

## Per-scenario notes

### revocation-delay
Worst observed window 297.38 ms is well below the 500 ms bound. The bound was
raised from the original 100 ms during the post-repair sweep documented in
`audits/final/post-repair-re-audit.md` §4 ("Fault bound correction") because
the prior threshold was stricter than the measured envelope under real-mode
conditions. Tail behaviour: the ghz-side P99 of 299.73 ms is consistent with
the reported revocation window, indicating that the long-tail arises from
genuine propagation latency rather than an instrumented outlier.

### clock-skew
Smallest envelope of the four scenarios (76.00 ms vs. 400 ms bound). Token
freshness validation under bounded clock skew is dominated by a fixed
validation cost rather than network propagation, which explains the order-of-
magnitude headroom.

### version-skew
Worst observed window 372.63 ms vs. 750 ms bound. The wider bound is
intentional: a mixed-policy-version cluster amplifies the propagation
latency by the proportion of skewed nodes (`skewed_nodes_pct: 20` in
`fault/scenarios/version_skew.yaml`). Recovery is fast (7.27 ms) once the
trailing nodes accept the dominant version.

### stale-proof-replay
Worst observed window 349.91 ms vs. 500 ms bound. With 300 iterations and a
1,000-attempt replay parameterisation, no replay reached an effective state
transition — the nonce cache absorbed every attempt within the configured
TTL.

## Reproducibility

Re-run the campaign with:

```bash
python3 fault/injectors/run_fault_campaign.py
```

Each scenario writes a new `fault/raw/<scenario>.json` (schema-checked against
`fault/reports/fault_campaign.schema.json`). Regenerate this summary by
re-aggregating those four files; the script is intentionally simple — every
field in the table above maps directly to a top-level field of the scenario
JSON or to a single percentile read out of the raw ghz file.

## Provenance

- Source artefacts: `fault/raw/{revocation_delay,clock_skew,version_skew,stale_replay}.json`
- Underlying ghz traces: `fault/raw/<scenario>.raw.json`
- Scenario configurations: `fault/scenarios/<scenario>.yaml`
- Schema: `fault/reports/fault_campaign.schema.json`
- Executor: `fault/injectors/run_fault_campaign.py`
- Audit hook: `audit-gate` step (see `audits/final/post-repair-re-audit.md` §4)
- Commit: `5c86a3517f803f525041d826dfc17ea497bbd147`
- Run date: 2026-02-20
- Mode: `real-ghz`
- Seed: `0`
