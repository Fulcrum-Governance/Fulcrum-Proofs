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
- `deployment-axiom`
  - Systems property declared as an axiom because it depends on runtime
    sandbox enforcement, not pure mathematics.

## Current baseline

| Name | Expected profile | Rationale |
|------|------------------|-----------|
| `Fulcrum.GameTheory.constrained_welfare_optimal` | `kernel-3` | Tight-budget welfare proof sits on the finite game-theory stack and inherits the standard classical/quotient support from Mathlib and the mixed-game bridge. |
| `Fulcrum.GameTheory.constrained_poa_exact` | `kernel-3` | Exact constrained PoA result depends on the same coordination-game and Nash-uniqueness machinery as the broader PoA proofs. |
| `Fulcrum.GameTheory.fulcrum_poa_bounded` | `kernel-3` | Public-facing PoA bound closes through Nash uniqueness and the classical finite-game surface. |
| `Fulcrum.GameTheory.nash_eq_allModerate` | `kernel-3` | Uniqueness proof uses the same game-theory encoding and classical finite reasoning stack as the bounded PoA theorem. |
| `Fulcrum.GameTheory.mixed_nash_exists` | `kernel-3` | Mixed Nash existence is routed through the vendored `Gametheory` Brouwer/Scarf bridge and therefore stays on the full classical kernel-3 profile. |
| `Fulcrum.budget_safety_guarantee` | `kernel-1` | Budget safety is the portable constructive exemplar: direct Nat reasoning, no quotient machinery, and no deployment assumptions. |
| `Fulcrum.RLM.canAccess` | `deployment-axiom` | Abstract sandbox-access predicate supplied by the runtime/container boundary, not proved inside Lean. |
| `Fulcrum.RLM.context_partition_isolation` | `deployment-axiom` | Boundary contract for partition isolation. The probe should continue to show exactly the deployment axiom set and nothing more. |

Spec drift note: the current mixed-Nash theorem exported by the repo is
`Fulcrum.GameTheory.mixed_nash_exists`, not
`MixedNashExistence.exists_nash_equilibrium`.

## Normalized probe baseline

```text
'Fulcrum.GameTheory.constrained_welfare_optimal' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.constrained_poa_exact' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.fulcrum_poa_bounded' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.nash_eq_allModerate' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.GameTheory.mixed_nash_exists' depends on axioms: [propext, Classical.choice, Quot.sound]
'Fulcrum.budget_safety_guarantee' depends on axioms: [propext]
'Fulcrum.RLM.canAccess' depends on axioms: [Fulcrum.RLM.canAccess]
'Fulcrum.RLM.context_partition_isolation' depends on axioms: [Fulcrum.RLM.canAccess,
 Fulcrum.RLM.context_partition_isolation]
```
