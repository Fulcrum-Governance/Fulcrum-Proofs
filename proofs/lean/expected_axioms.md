# Expected Axiom Profiles

This document is the human-readable and machine-checked baseline for
`probes/check_central_axioms.lean`.

`proofs/reproduce.sh` extracts the `text` code block in
"Normalized probe baseline" and diffs it against live probe output.

## Profile classes

- `kernel-3`: `[propext, Classical.choice, Quot.sound]`
  - Full Mathlib classical foundation. These theorems are still theorem-level
    proofs, but they rely on the standard classical/quotient kernel surface
    that shows up in many Mathlib-backed developments.
- `kernel-1`: `[propext]`
  - Constructive-only profile for simple invariants that do not pull in the
    full classical quotient stack.
- `kernel-2`: `[propext, Quot.sound]`
  - Choice-free arithmetic proofs whose reflective tactic certificates retain
    `Quot.sound`.
- `deployment-axiom`
  - Systems property declared as an axiom because it depends on runtime
    sandbox enforcement, not pure mathematics.

## Current baseline

| Name | Expected profile | Rationale |
|------|------------------|-----------|
| `Fulcrum.GameTheory.constrained_welfare_optimal` | `kernel-3` | Tight-budget welfare proof sits on the finite game-theory stack and inherits the standard classical/quotient support from Mathlib and the mixed-game bridge. |
| `Fulcrum.GameTheory.constrained_poa_exact` | `kernel-1` | Canonical exact-data theorem. Its six-clause `ExactFullClaim` covers all-moderate Nash existence and pointwise uniqueness, feasibility, exact `7*n` attainment, welfare optimality, and relational PoA at exactly one for every positive `n ≤ 12`. |
| `Fulcrum.GameTheory.constrained_poa_exact_real_compat` | `kernel-3` | Noncanonical compatibility/provenance preservation of the legacy Real theorem. It is downstream of the exact canonical module and never enters the canonical dependency cone. |
| `Fulcrum.GameTheory.exactFullClaim_iff_realFullClaim` | `kernel-3` | Named machine-checked equivalence between all six exact and legacy Real clauses. |
| `Fulcrum.GameTheory.exactCompleteDomain_iff_realCompleteDomain` | `kernel-3` | Complete-domain correspondence for every existing positive `BudgetParams` with only `B = 25*n` and `n ≤ 12`. |
| `Fulcrum.GameTheory.fulcrum_poa_bounded` | `kernel-3` | Public-facing PoA bound closes through Nash uniqueness and the classical finite-game surface. |
| `Fulcrum.GameTheory.nash_eq_allModerate` | `kernel-3` | Uniqueness proof uses the same game-theory encoding and classical finite reasoning stack as the bounded PoA theorem. |
| `Fulcrum.GameTheory.allModerate_not_nash_of_thirteen_le` | `kernel-3` | The Real-typed theorem proves only that the all-moderate profile ceases to be Nash for `agentCount ≥ 13`, witnessed by an aggressive unilateral deviation. |
| `Fulcrum.GameTheory.mixed_nash_exists` | `kernel-3` | Mixed Nash existence is routed through the vendored `Gametheory` Brouwer/Scarf bridge and therefore stays on the full classical kernel-3 profile. |
| `Fulcrum.budget_safety_guarantee` | `kernel-1` | Budget safety is the portable constructive exemplar: direct Nat reasoning, no quotient machinery, and no deployment assumptions. |
| `Fulcrum.RLM.canAccess` | `deployment-axiom` | Abstract sandbox-access predicate supplied by the runtime/container boundary, not proved inside Lean. |
| `Fulcrum.RLM.context_partition_isolation` | `deployment-axiom` | Boundary contract for partition isolation. The probe should continue to show exactly the deployment axiom set and nothing more. |
| `Fulcrum.GameTheory.constrained_poa_exact_int` | `kernel-2` | Additive welfare-only companion. It carries no Nash quantifier and is not the canonical full claim. |

`probes/check_exact_poa_axioms.lean` additionally asserts 100 individual
profiles: every theorem in the five canonical exact owner modules is either
axiom-free or exactly kernel-1, while every named correspondence and Real
compatibility theorem is measured in its separate kernel-0, kernel-1, or
kernel-3 class.

Spec drift note: the current mixed-Nash theorem exported by the repo is
`Fulcrum.GameTheory.mixed_nash_exists`, not
`MixedNashExistence.exists_nash_equilibrium`.

## Normalized probe baseline

```text
[check_central_axioms] 27 axiom profiles match inventory
'Fulcrum.GameTheory.constrained_welfare_optimal' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.constrained_poa_exact' depends on axioms: [propext]
'Fulcrum.GameTheory.constrained_poa_exact_real_compat' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.exactFullClaim_iff_realFullClaim' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.exactCompleteDomain_iff_realCompleteDomain' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'Fulcrum.GameTheory.fulcrum_poa_bounded' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.nash_eq_allModerate' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.allModerate_not_nash_of_thirteen_le' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.mixed_nash_exists' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.budget_safety_guarantee' depends on axioms: [propext]
'Fulcrum.RLM.canAccess' depends on axioms: [Fulcrum.RLM.canAccess]
'Fulcrum.RLM.context_partition_isolation' depends on axioms: [Fulcrum.RLM.canAccess,
 Fulcrum.RLM.context_partition_isolation]
'Fulcrum.capped_prior_strict_responsiveness' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.governed_kernel_pre_execution_safety' depends on axioms: [propext]
'Fulcrum.high_risk_execution_kernel_guarantee' depends on axioms: [propext]
'Fulcrum.GameTheory.constrained_poa_exact_int' depends on axioms: [propext, Quot.sound]
```
