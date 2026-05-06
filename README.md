# Fulcrum-Proofs

[![proof-gate](https://github.com/Fulcrum-Governance/Fulcrum-Proofs/actions/workflows/proof-gate.yml/badge.svg)](https://github.com/Fulcrum-Governance/Fulcrum-Proofs/actions/workflows/proof-gate.yml) [![Lean 4.29.0-rc4](https://img.shields.io/badge/Lean-v4.29.0--rc4-0f766e)](https://github.com/leanprover/lean4/releases/tag/v4.29.0-rc4) [![mathlib 06e9473](https://img.shields.io/badge/mathlib-06e9473-1d4ed8)](https://github.com/leanprover-community/mathlib4/tree/06e947358d88e36af006f915f79a04a10fd43cc4) [![License: MIT](https://img.shields.io/badge/License-MIT-f59e0b.svg)](LICENSE) [![sorry count: 0](https://img.shields.io/badge/sorry-0-15803d)](proofs/lean/scripts/check_no_sorry.sh) [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19900714.svg)](https://doi.org/10.5281/zenodo.19900714)

The formal core of the Fulcrum governance kernel — proof and evidence repository for Fulcrum governance claims.

Fulcrum is a governance kernel: a portable, typed, pre-execution control plane that sits between intent and action, enforces bounded invariants (policy, budget, trust, audit), and emits evidence-grade audit artifacts. This repository holds the machine-checkable proofs that ground those invariants.

## Part of the Fulcrum Architecture

| Repo | Role | License |
|------|------|---------|
| **[fulcrum-io](https://github.com/Fulcrum-Governance/fulcrum-io)** | Runtime control plane: policy engine, envelopes, Foundry, MCP proxy, dashboard | BSL 1.1 |
| **[governance-interception-layer](https://github.com/Fulcrum-Governance/governance-interception-layer)** | Out-of-process enforcement boundary: transport adapters, shared governance pipeline | Apache 2.0 |
| **[fulcrum-trust](https://github.com/Fulcrum-Governance/fulcrum-trust)** | Trust engine: Beta(α,β) evaluator, circuit breaker, LangGraph adapter | Apache 2.0 |
| **Fulcrum-Proofs** (this repo) | Formal core: Lean 4 proofs, TLA+ models, benchmark and audit evidence | MIT |

Contributing: [CONTRIBUTING.md](CONTRIBUTING.md) · Security: [SECURITY.md](SECURITY.md) · Changelog: [CHANGELOG.md](CHANGELOG.md) · Citation: [CITATION.cff](CITATION.cff)

This repository is the source of truth for:
- formal proofs (Lean)
- distributed safety models (TLA+)
- reproducible benchmark evidence
- fault-injection evidence
- compliance evidence mappings
- final re-audit closure artifacts

## Claim Taxonomy

Every public claim backed by this repository is labeled with exactly one of:

| Label | Meaning | Example |
|-------|---------|---------|
| **Proved** | Machine-checkable Lean 4 proof, zero sorry | Budget Safety Invariant |
| **Tested** | Empirical validation with published data | C-005 at 1M tokens |
| **Implemented** | Exists in code, passes tests, deployed or deployable | GIL 4-stage pipeline |
| **Simulated** | Benchmarked in controlled environment, not production | k6 scale suite at 1000 VUs |
| **Conjectured** | Reasoned but not yet closed | 10M-token extrapolation |

## Decision Taxonomy

Every governance decision produced by the kernel is labeled with exactly one of:

| Label | What it means | Audit trail shows |
|-------|--------------|-------------------|
| **Proved** | Lean 4 invariant check passed | Theorem ID + proof artifact |
| **Deterministic** | Static policy rule matched | Policy rule ID + match reason |
| **Classified** | Semantic Judge / probabilistic evaluation | Model ID + confidence + reasoning |
| **Human-approved** | Human reviewed and approved | Approver ID + timestamp |

No decision is ever labeled generic "governed." The taxonomy is the product's signature. Canonical language: [`NARRATIVE_SYSTEM.md`](https://github.com/Fulcrum-Governance/fulcrum-io/blob/main/.claude/sprint/kernel-reframe/NARRATIVE_SYSTEM.md) in fulcrum-io.

## Scope Policy

Only claims that are formally provable or empirically reproducible are allowed to remain `Proven`.
Claims without closure artifacts must be marked `Incomplete`.

## Coupling Model

This repository is contract-coupled to the `Fulcrum` repository:
- imports protocol contracts and selected interface snapshots
- does not depend on Fulcrum runtime code for execution

## Repository Layout

- `claims/`: canonical claim sources for this repo. Internal authority order:
  - `claims/theorem_inventory.yaml` (v2, last updated 2026-05-03) — **theorem-level
    canonical source**. Reflects current proof state (`sorry_count`, `status`,
    `theorem_id`) and takes precedence over `claim_ledger.yaml` for any
    theorem-status question. Closes contradiction-ledger F-042.
  - `claims/claim_closure.yaml` — claim-level closure manifest, the
    machine-readable proof-to-runtime mapping consumed by CI gates.
  - `claims/claim_scope.yaml` — claim definitions / scope.
  - `claims/claim_ledger.yaml` — historical ledger; superseded by
    `theorem_inventory.yaml` for theorem-level status.
  - `claims/waivers.yaml` — open waivers (with expiry dates).
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

## Trust Termination Proofs

The `proofs/lean/Proofs/TrustTermination.lean` file formalizes the Beta(alpha,beta) trust model's termination guarantee — the mathematical basis for `fulcrum-trust`'s circuit breaker.

### Theorem Inventory

| Theorem | Statement | Status |
|---------|-----------|--------|
| `trust_monotone_decreasing` | Each failure strictly decreases trust | Proven |
| `trust_failure_degrades` | Failure makes trust strictly lower (via `trustLt`) | Proven |
| `trust_threshold_reachable` | For any threshold, exists beta_star below it | Proven |
| `trust_termination_invariant` | Circuit open iff trust below threshold (well-formed states) | Proven |
| `trust_safety_invariant` | Circuit closed iff trust at/above threshold | Proven |
| `trust_cumulative_degradation` | More failures = lower trust (generalized monotonicity) | Proven |
| `trust_guaranteed_termination` | Continued failures from any start guarantee termination | Proven |
| `terminated_is_absorbing` | No valid transition leaves TERMINATED | Proven |
| `closed_transitions` | CLOSED can only go to OPEN or TERMINATED | Proven |
| `no_closed_to_halfOpen` | Cannot skip to recovery without termination | Proven |

### Claims (C-022)

| Claim | Statement | Status |
|-------|-----------|--------|
| C-022 | Trust circuit breaker guarantees agent termination under sustained failure | Proven |

### Technical Approach

All proofs use Nat cross-multiplication to encode rational inequalities, avoiding Lean 4 `Rat` type entirely. The trust score `Trust(alpha, beta) = (alpha + 1) / (alpha + beta + 2)` is represented as a numerator/denominator pair, and ordering is defined via `trustNum * otherDen < otherNum * thisDen`. This makes `omega` and `nlinarith` the workhorse tactics.

The circuit breaker models 4 states matching the Python implementation: CLOSED, OPEN, HALF_OPEN, TERMINATED. TERMINATED is an admin override (absorbing state).

Reference implementation: `fulcrum-trust/fulcrum_trust/evaluator.py`, `manager.py`

## RLM Interface Contracts

The `proofs/lean/Proofs/RLMContracts.lean` file defines formal interface contracts for the Recursive Language Model inference loop.

### Contract Inventory

| Contract | Type | Status |
|----------|------|--------|
| Context partition isolation | Axiom | Axiomatized (sandbox property) |
| Recursion depth bounded | Theorem | Proven |
| Step decreases partitions (termination measure) | Theorem | Proven |
| Answer readiness monotonic | Theorem | Proven |
| Token budget enforced | Theorem | Proven |
| Answer on completion | Theorem | Proven |

### Claims (C-023)

| Claim | Statement | Status |
|-------|-----------|--------|
| C-023 | RLM inference loop satisfies bounded termination and resource constraints | Proven |

These are *interface contracts* — they specify correctness criteria that any RLM implementation must satisfy. They mirror the Go interfaces in `fulcrum-io/internal/rlm/interfaces.go`. The step function models the core loop body in `internal/rlm/inference/loop.go`.

## Game Theory Proofs

The `proofs/lean/Proofs/GameTheory/` directory contains a Lean 4 + Mathlib4 formalization of Fulcrum's multi-agent coordination mechanism as a finite normal-form game. The proof layer addresses Nash equilibrium existence, incentive properties, coordination efficiency, and the bridge from budget enforcement to game-theoretic guarantees.

### Lean Module Map

| Module | Role |
|--------|------|
| `Definitions.lean` | Normal-form game structures, Nash equilibrium, social welfare, PoA |
| `FulcrumGame.lean` | Fulcrum-specific game: 4 actions, payoff function, budget params |
| `SumUpdateLemmas.lean` | `Finset.sum` + `Function.update` decomposition helpers |
| `NashExistence.lean` | All-moderate is Nash; noncompliant is strictly dominated |
| `MixedNashExistence.lean` | Mixed-strategy Nash via PMF↔stdSimplex bridge to math-xmum/Brouwer `ExistsNashEq` |
| `IncentiveCompatibility.lean` | Proportional allocation is **not** DSIC (counterexample) |
| `CoordinationEfficiency.lean` | Social welfare bounds and Price of Anarchy |
| `BudgetGameBridge.lean` | Connects `budget_safety_guarantee` to game model |

### Claims (C-018 through C-021)

| Claim | Statement | Status |
|-------|-----------|--------|
| C-018 | Coordination game admits a Nash equilibrium | Proven (sorry-free; mixed Nash via Brouwer-via-Scarf for arbitrary finite games; pure-strategy uniqueness verified for agentCount ≤ 12) |
| C-019 | Proportional allocation is **not** DSIC under current utility | Proven |
| C-020 | Constrained Price of Anarchy is 1.0 under tight budget | Proven (formal constrained PoA = 1.0 for agentCount ≤ 12; unconstrained reference upper bound PoA ≤ 9/7) |
| C-021 | Budget enforcement grounds the game model | Proven |

### Proof Portfolio Summary

| File | Theorems | Sorry-free? |
|------|----------|-------------|
| `BasicInvariants.lean` | 4 (budget safety, privilege subset) | Yes |
| `TemporalConservationSpec.lean` | 3 (temporal conservation, revocation) | Yes |
| `TrustTermination.lean` | 10 (trust model, circuit breaker) | Yes |
| `RLMContracts.lean` | 8 (4 proven + 1 axiom + helpers) | Yes (1 axiom) |
| `GameTheory/*.lean` | 10+ (Nash, PoA, incentives, bridge) | Yes |

### Remaining Sorry Holes (0 of 16 original)

All originally-tracked sorry holes are closed. The zero-sorry claim covers all first-party Lean proofs in `Proofs/`. The vendored dependency (`vendor/Gametheory/`, MIT-licensed from math-xmum/Brouwer) is upstream code whose proof integrity is inherited, not re-verified by `check_no_sorry.sh`. `MixedNashExistence.mixed_nash_exists` was closed via math-xmum/Brouwer's `ExistsNashEq` (Brouwer fixed-point on product simplices via Scarf's Lemma) through a PMF↔stdSimplex bridge; the previous `kakutani_fixed_point_theorem` axiom has been removed.

`CoordinationEfficiency.fulcrum_poa_bounded` was closed via `NashUniqueness.lean` (PR #5) — all equilibria under tight budget are all-moderate, giving PoA ≤ 9/7.

### Incentive Compatibility Correction

The original plan assumed proportional allocation is DSIC. Mathematical review found this is **false** under the utility model `allocationUtility = -|allocation - trueNeed|`: under budget sufficiency, agents can profitably under-report to move their allocation closer to their true need. The Lean files now prove this negative result via an explicit two-agent counterexample (n=2, budget=20, needs=(5,5)).

For the audited simulation instance (`n=5`, `budget=125`), best-response dynamics converge to the welfare-optimal all-moderate profile, so realized PoA is `1.0`. The Lean theorem still states the general upper bound `PoA ≤ 9/7`.

See `proofs/lean/Proofs/GameTheory/README.md` for a detailed module guide and assumption register.

## Local Quick Start

> **Vendored Gametheory dependency** (as of 2026-05-03). The forked Mathlib game-theory package (Brouwer / Kakutani / `ExistsNashEq` through the PMF ↔ stdSimplex bridge) is now vendored at `proofs/lean/vendor/Gametheory/` — no sibling clone required. Lake resolves the dependency from the in-repo vendor path directly.
>
> Provenance: `proofs/lean/vendor/Gametheory/UPSTREAM.md` documents the upstream URL (`math-xmum/Brouwer`), the ported-from SHA (`1355a1c`), MIT license preservation, and the manual sync procedure if upstream advances.
>
> This closes contradiction-ledger entry F-020 and `Fulcrum-Governance/Fulcrum-Proofs#16`. The plan-authorized admin-bypass precedent on `proof-gate` is now bounded to historical use (4 PRs total: Wave 2 #13, Wave 3 #14/#15/#17). New Proofs PRs from this point forward should pass `proof-gate` naturally.

```bash
# 1) Sync contracts from the sibling Fulcrum checkout
./contracts/sync/sync_contracts.sh
# Or override the source checkout explicitly:
# ./contracts/sync/sync_contracts.sh --source <path-to-fulcrum-io>

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
- `Proven-with-sorry`: Lean structure is machine-checked but contains `sorry` placeholders in non-critical sub-goals *(currently unused — 0 sorrys repo-wide)*
- `Incomplete`: scoped but missing closure artifacts
- `Refuted`: counterexample/contradiction established

## Disclaimer

This repository provides engineering evidence and formal artifacts. It is not legal certification.
