# Fulcrum-Proofs — Agent Context

**Last updated:** 2026-08-12

---

## Four-Repo Architecture

This is one of four repositories under the `Fulcrum-Governance` GitHub org.

| Repo | Local Path | Language | Purpose |
|------|-----------|----------|---------|
| **fulcrum-io** | `../Fulcrum` | Go 1.26.3 | Backend platform: gRPC server, REST gateway, MCP endpoint, policy engine, cognitive layer, foundry, entropy monitor |
| **Fulcrum-Boundary** | `../Fulcrum-Boundary` | Go 1.25.0 (toolchain go1.26.4) | Out-of-process enforcement boundary: transport adapters, shared governance pipeline, cross-transport parity |
| **fulcrum-trust** | `../fulcrum-trust` | Python 3.9+ | Trust model authority: beta-distribution trust math, circuit breaker, LangGraph adapter, IPC bridge, RLM prototype |
| **Fulcrum-Proofs** (this repo) | `.` | Lean 4 / TLA+ / Python | Formal verification: Lean 4 proofs, TLA+ model checking, benchmark evidence, claim ledger |

### Cross-Repo Relationships
- **Contract sync**: `contracts/snapshots/` mirrors proto definitions and Go interfaces from `fulcrum-io`. Synced via `scripts/sync-contracts.sh` in the IO repo.
- **Boundary evidence**: Runtime enforcement parity for transport adapters lives in the Fulcrum-Boundary repo; proof claims should reference it only through explicit closure artifacts.
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

0 remaining sorry holes across all first-party Lean proofs (down from 16). The previously axiomatized
`kakutani_fixed_point_theorem` has been removed.

All theorems are sorry-free, including:
- `mixed_nash_exists` (MixedNashExistence.lean) — closed via math-xmum/Brouwer's
  `ExistsNashEq` (Brouwer FPT on product simplices via Scarf's Lemma) through a
  PMF ↔ stdSimplex bridge. Vendored dependency:
  `proofs/lean/vendor/Gametheory/`.
- `fulcrum_poa_bounded` (PoA ≤ 9/7, NashUniqueness.lean)
- `constrained_poa_exact` (CoordinationEfficiencyExact.lean) — canonical
  claim-complete exact-data theorem, measured exactly `[propext]`
- `constrained_poa_exact_real_compat` (CoordinationEfficiency.lean) —
  noncanonical legacy Real compatibility/provenance theorem
- `trust_guaranteed_termination` + 9 companion theorems (TrustTermination.lean)
- 4 RLM interface contracts + 1 axiom (RLMContracts.lean)

**Proof portfolio:** sorry-free theorems across the first-party Lean modules inventoried in
`claims/theorem_inventory.yaml`; claims C-004 through C-025 per `claims/claim_scope.yaml`. The vendored
`proofs/lean/vendor/Gametheory/` dependency is upstream code whose proof integrity is inherited, not
re-verified by `check_no_sorry.sh`.

## Branch Protection (Strict)

All changes must go through PRs. 6 CI gates required:
- `proof-gate` — Lean proof replay (~2 min)
- `model-gate` — TLA+ model checking (~15 min)
- `bench-gate`, `fault-gate`, `evidence-gate`, `audit-gate` — fast (<15s each)

Bot review threads (Codex, Qodo) must be resolved before merge. Use GraphQL `resolveReviewThread` mutation if needed.

## Release Lineage

Latest tag: **`v0.2.0`**. Both tags are lightweight; only `v0.2.0` has a GitHub Release.

| Tag | Date | What changed |
|-----|------|--------------|
| `v0.1.0` | 2026-05-03 | Public-flip readiness: `proofs/reproduce.sh` one-shot verification entrypoint, `probes/check_central_axioms.lean` + `expected_axioms.md` axiom-surface baseline, initial `CITATION.cff`, `HYPOTHESES.md`, README badges, `axiom_profile` metadata across the theorem inventory, portable contract-sync/evidence paths. |
| `v0.2.0` | 2026-07-11 | Published-supplement parity + kernel-level probe gate: `GovernedKernel.lean` and `KernelVariants.lean` ported from the published D4 Zenodo supplement, `CoordinationEfficiencyInt.lean` integer-audit companion, sorryAx probe wired into `proof-gate.yml` as a required step, claims C-024/C-025 added, C-005 flipped `proven → tested` per the lapsed waiver. Archived at DOI `10.5281/zenodo.21314452`. |

> **Trap:** `v0.3.0` belongs to **`fulcrum-trust`** (PyPI), a different repo. Do not "correct" Proofs
> upward — Proofs' latest tag is `v0.2.0`.

Per-release detail lives in [`CHANGELOG.md`](CHANGELOG.md).

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

---

## Lean 4 AI Tooling

### lean-lsp-mcp (MCP Server)

Provides Language Server Protocol access for LLM agents. Enables real-time diagnostics, goal state inspection, hover docs, completions, and external theorem search (LeanSearch, Loogle, Lean Hammer).

**Claude Code:** Already configured as user-scoped MCP server.
```bash
claude mcp add --transport stdio --scope user lean-lsp -- uvx lean-lsp-mcp
```

**Codex:** Set `LEAN_PROJECT_PATH` before running:
```bash
export LEAN_PROJECT_PATH="$(git rev-parse --show-toplevel)/proofs/lean"
```

### lean4-skills (Workflow Pack)

Structured prove/review/golf loop for AI coding agents.

**Location:** `$HOME/.codex/skills/lean4-skills/plugins/lean4/skills/lean4/SKILL.md`

**Environment:**
- `LEAN4_PLUGIN_ROOT=$HOME/.codex/skills/lean4-skills/plugins/lean4`
- `LEAN4_SCRIPTS=$LEAN4_PLUGIN_ROOT/lib/scripts`
- `LEAN4_REFS=$LEAN4_PLUGIN_ROOT/skills/lean4/references`

### Usage Notes
- lean-lsp-mcp requires `lake build` to have been run at least once (warnings like sorry are OK)
- External search tools (LeanSearch, Loogle) are rate-limited to 3 requests per 30 seconds
- Set `LEAN_LOG_LEVEL=WARNING` to reduce noise in agent sessions

## Commit attribution

Never add AI, Claude, or Anthropic co-authorship or attribution: no `Co-Authored-By` trailer, no "Generated with Claude" lines, no AI credit anywhere (commit messages, PR titles/bodies, changelogs, code comments). Author as the repository owner only.
