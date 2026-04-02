<!-- product-bible | version: 1.0.0 | last-updated: 2026-02-22 -->

# Product Definition

The canonical product bible for the Fulcrum project (spanning all three repos) lives in the Fulcrum main repository:

**[Fulcrum/product/INDEX.md](https://github.com/Fulcrum-Governance/fulcrum-io/blob/main/product/INDEX.md)**

## This repo's role

`Fulcrum-Proofs` is the **claim and evidence authority**. It owns:
- Claim ledger (`claims/claim_ledger.yaml`) — every external technical claim with status: proven, incomplete, or waived
- Formal proofs (`proofs/lean/`) — Lean 4 machine-checked proofs
- TLA+ models (`models/tla/`) — distributed safety specifications
- Benchmark harness (`benchmarks/`) — reproducible performance evidence
- Fault injection (`fault/`) — failure scenario testing
- Compliance mappings (`compliance/`) — EU AI Act, SOX, SOC 2

This repo contains **no product code**. It is infrastructure for claims, investor credibility, and regulatory evidence.

## C-005 Status

Claim C-005 (long-context ≥10M tokens) is **PROVEN — 28/28 benchmark pass, evidence at `benchmarks/raw/c005-final-report.json`.**

## Relationship to Fulcrum

Contract interfaces are synced from Fulcrum main via `scripts/proofs-sync-and-gate.sh`.
Proof gates are enforced in Fulcrum's `make proofs-gate`.

See [ADR-003](https://github.com/Fulcrum-Governance/fulcrum-io/blob/main/product/ADRs/003-three-repo-architecture.md) for the rationale.
