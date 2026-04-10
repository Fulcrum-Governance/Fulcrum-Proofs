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

## Game Theory Proofs

The `proofs/lean/Proofs/GameTheory/` directory contains a Lean 4 + Mathlib4 formalization of Fulcrum's multi-agent coordination mechanism as a finite normal-form game. The proof layer addresses Nash equilibrium existence, incentive properties, coordination efficiency, and the bridge from budget enforcement to game-theoretic guarantees.

### Lean Module Map

| Module | Role |
|--------|------|
| `Definitions.lean` | Normal-form game structures, Nash equilibrium, social welfare, PoA |
| `FulcrumGame.lean` | Fulcrum-specific game: 4 actions, payoff function, budget params |
| `SumUpdateLemmas.lean` | `Finset.sum` + `Function.update` decomposition helpers |
| `NashExistence.lean` | All-moderate is Nash; noncompliant is strictly dominated |
| `MixedNashExistence.lean` | Mixed-strategy Nash via expected payoff and Kakutani axiom |
| `IncentiveCompatibility.lean` | Proportional allocation is **not** DSIC (counterexample) |
| `CoordinationEfficiency.lean` | Social welfare bounds and Price of Anarchy |
| `BudgetGameBridge.lean` | Connects `budget_safety_guarantee` to game model |

### Claims (C-018 through C-021)

| Claim | Statement | Status |
|-------|-----------|--------|
| C-018 | Coordination game admits a Nash equilibrium | Proven-with-sorry (1 Kakutani gap) |
| C-019 | Proportional allocation is **not** DSIC under current utility | Proven |
| C-020 | Price of Anarchy bounded at 9/7 | Proven (formal upper bound 9/7; audited simulation realized PoA = 1.0) |
| C-021 | Budget enforcement grounds the game model | Proven |

### Remaining Sorry Holes (1 of 16 original)

| Location | Reason |
|----------|--------|
| `MixedNashExistence.mixed_nash_exists` | Kakutani FPT not available in Mathlib4; external repos (harfe, math-xmum) incompatible with Lean 4.29 |

`CoordinationEfficiency.fulcrum_poa_bounded` was closed via `NashUniqueness.lean` (PR #5) — all equilibria under tight budget are all-moderate, giving PoA ≤ 9/7.

### Incentive Compatibility Correction

The original plan assumed proportional allocation is DSIC. Mathematical review found this is **false** under the utility model `allocationUtility = -|allocation - trueNeed|`: under budget sufficiency, agents can profitably under-report to move their allocation closer to their true need. The Lean files now prove this negative result via an explicit two-agent counterexample (n=2, budget=20, needs=(5,5)).

For the audited simulation instance (`n=5`, `budget=125`), best-response dynamics converge to the welfare-optimal all-moderate profile, so realized PoA is `1.0`. The Lean theorem still states the general upper bound `PoA ≤ 9/7`.

See `proofs/lean/Proofs/GameTheory/README.md` for a detailed module guide and assumption register.

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

- Go 1.26.2
- Python 3.12+
- Node 20+
- Java 17+ (for TLC)
- Lean 4.29.0-rc4 + Mathlib4 via `elan`/`lake`

## Status Levels

- `Proven`: artifact-backed formal/empirical closure exists
- `Proven-with-sorry`: Lean structure is machine-checked but contains `sorry` placeholders in non-critical sub-goals
- `Incomplete`: scoped but missing closure artifacts
- `Refuted`: counterexample/contradiction established

## Disclaimer

This repository provides engineering evidence and formal artifacts. It is not legal certification.
