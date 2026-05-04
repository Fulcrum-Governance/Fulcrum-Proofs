# Research Validation Report

Status: completed for in-scope closure (C-005 waived).

## Primary-source validation
- Lean/Lake toolchain references sourced from official Lean documentation.
- TLA+/TLC execution references sourced from the TLA+ project release/docs.
- k6 threshold and metrics behavior sourced from Grafana k6 documentation.
- Artifact review framing sourced from ACM artifact review resources.

## Citation metadata consistency
- Ran: `python3 scripts/reference_sanity_check.py --input audits/post-repair/references.txt`
- Result: no arXiv year mismatch flags in this sprint pack.

## Empirical protocol quality (in scope)
- Benchmarks use real gRPC calls (`ghz`) and emit raw JSON artifacts with commit linkage.
- Fault campaign uses real gRPC calls and measured envelopes; no simulated mode accepted by gate.
- Reproducibility rule enforced through repeated runs in benchmark manifest.

## Remaining gap
- `C-005` remains intentionally incomplete under waiver:
  - Missing validated 10M+ long-context dataset card and protocol.
  - No claim of near-perfect recall is made in sprint closure output.
