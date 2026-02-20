# Fulcrum-Proofs

Proof and evidence repository for Fulcrum governance claims.

This repository is the source of truth for:
- formal proofs (Lean)
- distributed safety models (TLA+)
- reproducible benchmark evidence
- fault-injection evidence
- compliance evidence mappings
- final re-audit closure artifacts

## Scope Policy

Only claims that are formally provable or empirically reproducible are allowed to remain `Proven`.
Claims without closure artifacts must be marked `Incomplete`.

## Coupling Model

This repository is contract-coupled to the `Fulcrum` repository:
- imports protocol contracts and selected interface snapshots
- does not depend on Fulcrum runtime code for execution

## Repository Layout

- `claims/`: claim scope, theorem inventory, claim ledger
- `contracts/`: imported contracts + sync tooling
- `proofs/lean/`: machine-checkable proofs and replay scripts
- `models/tla/`: distributed fault semantics and model checking
- `benchmarks/`: reproducible benchmark harness and reports
- `fault/`: fault-injection scenarios and campaign outputs
- `compliance/`: engineering evidence mappings
- `audits/`: post-repair and final closure artifacts
- `skills/`: Codex skills and references for proof program orchestration
- `.claude/agents/`: complementary Claude agents
- `scripts/`: gate and utility scripts
- `.github/workflows/`: CI/CD gates

## Local Quick Start

```bash
# 1) Sync contracts from Fulcrum repo
./contracts/sync/sync_contracts.sh --source /Users/td/ConceptDev/Projects/Fulcrum

# 2) Run formal proof replay
./proofs/lean/scripts/replay.sh

# 3) Run TLA+ model checks
./models/tla/scripts/run_tlc.sh

# 4) Run light benchmark evidence generation
python3 benchmarks/harness/run_benchmarks.py \
  --manifest benchmarks/manifests/benchmark_manifest.yaml \
  --out benchmarks/reports/latest-benchmark-run.json

# 5) Run fault campaign
python3 fault/injectors/run_fault_campaign.py \
  --scenario fault/scenarios/revocation_delay.yaml \
  --out fault/reports/latest-fault-campaign.json

# 6) Validate evidence gates
python3 scripts/evidence_gate.py
python3 scripts/audit_gate.py
```

## Bootstrap and Governance Setup

```bash
# Install local toolchain prerequisites
./scripts/bootstrap_toolchains.sh

# Initialize GitHub environments and branch protections
./scripts/github_bootstrap.sh --owner Fulcrum-Governance --repo Fulcrum-Proofs
```

Branch protection targets on `main`:
- required status checks: `proof-gate`, `model-gate`, `evidence-gate`
- pull-request reviews required
- force-push blocked

## Toolchain

- Go 1.24.13
- Python 3.12+
- Node 20+
- Java 17+ (for TLC)
- Lean 4 via `elan`/`lake`

## Status Levels

- `Proven`: artifact-backed formal/empirical closure exists
- `Incomplete`: scoped but missing closure artifacts
- `Refuted`: counterexample/contradiction established

## Disclaimer

This repository provides engineering evidence and formal artifacts. It is not legal certification.
