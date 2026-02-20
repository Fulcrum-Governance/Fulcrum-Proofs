# Fulcrum-Proofs Benchmark Validator

Generate reproducible benchmark artifacts and validate latency claim evidence.

## Use this skill when
- Producing p50/p95/p99 evidence.
- Running PR or nightly benchmark gates.

## Workflow
1. Execute `make bench-gate` or `make bench-nightly`.
2. Validate schemas in `benchmarks/reports/`.
3. Confirm run manifest, seed, and commit linkage.
4. Record residual uncertainty and sampling limits.

## Guardrails
- No performance claims without raw JSON artifacts.
- CI results must be reproducible with same manifest and seed.
