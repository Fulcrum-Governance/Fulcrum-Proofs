# Fulcrum-Proofs — Agent Context

**Last updated:** 2026-04-17

---

## Four-Repo Architecture

This is one of four repositories under the `Fulcrum-Governance` GitHub org.

| Repo | Local Path | Language | Purpose |
|------|-----------|----------|---------|
| **fulcrum-io** | `/Users/td/ConceptDev/Projects/Fulcrum` | Go 1.26.2 | Backend platform: gRPC server, REST gateway, MCP endpoint, policy engine, cognitive layer, foundry, entropy monitor |
| **governance-interception-layer** | `/Users/td/ConceptDev/Projects/governance-interception-layer` | Go 1.26.2 | Out-of-process enforcement boundary: transport adapters, shared governance pipeline, cross-transport parity |
| **fulcrum-trust** | `/Users/td/ConceptDev/Projects/fulcrum-trust` | Python 3.9+ | Trust model authority: beta-distribution trust math, circuit breaker, LangGraph adapter, IPC bridge, RLM prototype |
| **Fulcrum-Proofs** (this repo) | `/Users/td/ConceptDev/Projects/Fulcrum-Proofs` | Lean 4 / TLA+ / Python | Formal verification: Lean 4 proofs, TLA+ model checking, benchmark evidence, claim ledger |

### Cross-Repo Relationships
- **Contract sync**: `contracts/snapshots/` mirrors proto definitions and Go interfaces from `fulcrum-io`. Synced via `scripts/sync-contracts.sh` in the IO repo.
- **GIL evidence boundary**: Runtime enforcement parity for transport adapters lives in the GIL repo; proof claims should reference it only through explicit closure artifacts.
- **Product bible**: Canonical product definition lives in `fulcrum-io/product/`.
- **Claim discipline**: `fulcrum-io/CLAUDE.md` references proof status from this repo. Keep in sync.

---

## Build & Test

```bash
# Lean 4 proofs (requires elan toolchain, ~20 min first build for Mathlib4)
cd proofs/lean && lake build

# TLA+ model checking (requires Java 17+)
make model-gate

# Benchmark evidence (requires Python 3.12+)
make bench-gate

# All gates
make proof-gate model-gate bench-gate fault-gate evidence-gate audit-gate
```

## Sorry Status

1 remaining sorry hole (down from 16):
- `MixedNashExistence.mixed_nash_exists` — Kakutani FPT unavailable in Mathlib4

All other theorems are sorry-free, including:
- `fulcrum_poa_bounded` (PoA ≤ 9/7, NashUniqueness.lean)
- `trust_guaranteed_termination` + 9 companion theorems (TrustTermination.lean)
- 4 RLM interface contracts + 1 axiom (RLMContracts.lean)

**Total proof portfolio:** 20+ sorry-free theorems across 5 files, 23 claims (C-004 through C-023).

## Branch Protection (Strict)

All changes must go through PRs. 6 CI gates required:
- `proof-gate` — Lean proof replay (~2 min)
- `model-gate` — TLA+ model checking (~15 min)
- `bench-gate`, `fault-gate`, `evidence-gate`, `audit-gate` — fast (<15s each)

Bot review threads (Codex, Qodo) must be resolved before merge. Use GraphQL `resolveReviewThread` mutation if needed.

## Claim Lifecycle

Three files govern claim metadata:

| File | Purpose |
|------|---------|
| `claims/claim_scope.yaml` | Claim statements, types, closure criteria, status |
| `claims/claim_ledger.yaml` | Links claims to evidence artifacts |
| `claims/theorem_inventory.yaml` | Individual Lean theorems, assumptions, sorry counts |

## Conventions

- Conventional commits: `type(scope): message`
- Never force-push main
- Never commit secrets
