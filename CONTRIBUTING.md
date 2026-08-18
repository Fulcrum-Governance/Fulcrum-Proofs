# Contributing to Fulcrum-Proofs

## Replaying Proofs

```bash
# Install Lean 4 toolchain
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh -s -- -y

# Build all Lean proofs (fetches Mathlib4 on first run; expect ~20 min)
cd proofs/lean && lake build
```

## Sorry Audit

Check for remaining `sorry` placeholders:

```bash
rg '\bsorry\b' proofs/lean/Proofs/ --glob '*.lean'
```

As of 2026-04-28 there are **0 remaining sorry holes** (all 16 originally tracked sorrys closed). `MixedNashExistence.mixed_nash_exists` was closed via math-xmum/Brouwer's `ExistsNashEq` (Brouwer fixed-point on product simplices via Scarf's Lemma) through a PMF↔stdSimplex bridge; the previous `kakutani_fixed_point_theorem` axiom has been removed.

## Running Other Gates

```bash
make proof-gate       # Lean proof replay
make model-gate       # TLA+ model checking (requires Java 17+)
FULCRUM_SOURCE_REPO=/absolute/path/to/clean/Fulcrum make bench-gate  # Benchmark evidence (requires Python 3.12+)
make fault-gate       # Fault injection campaigns
make evidence-gate    # Full evidence validation
make audit-gate       # Audit closure check
```

## Claim Lifecycle

Claims progress through these statuses: `Incomplete` -> `Proven-with-sorry` -> `Proven` (or `Refuted`).

Three files govern claim metadata:

| File | Purpose |
|------|---------|
| `claims/claim_scope.yaml` | Defines each claim's statement, type, closure criteria, and current status |
| `claims/claim_ledger.yaml` | Links claims to their evidence artifacts |
| `claims/theorem_inventory.yaml` | Tracks individual Lean theorems, assumptions, and sorry counts |

When closing a sorry hole or adding a new theorem:
1. Update the Lean proof
2. Run `lake build` to confirm the build passes
3. Run the sorry audit to confirm the count decreased
4. Update `theorem_inventory.yaml` (proof_status, sorry_count, notes)
5. Update `claim_scope.yaml` and `claim_ledger.yaml` if claim status changes

## Branch Protection

The `main` branch requires:
- Passing CI gates: `proof-gate`, `model-gate`, `evidence-gate`
- Pull request review
- No force-push

All proof work should be done on feature branches and merged via PR.

## Code Style

- Lean files use `set_option autoImplicit false` and `open scoped BigOperators`
- No unnecessary comments; let theorem names and type signatures self-document
- Match existing `namespace Fulcrum.GameTheory` and import patterns
