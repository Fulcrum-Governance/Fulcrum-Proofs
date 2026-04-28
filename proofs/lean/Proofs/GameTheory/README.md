# Game Theory Proof Layer

Lean 4 + Mathlib4 formalization of Fulcrum's multi-agent coordination mechanism.

## Module Dependency Graph

```
BasicInvariants
       |
  Definitions
       |
   FulcrumGame
       |
  SumUpdateLemmas
    /    |     \          \
Nash   Mixed   Nash      BudgetGame
Exist  Nash    Uniqueness  Bridge
  |    Exist      |
  |          Coord
  |          Efficiency
  |               |
  IncentiveCompatibility
```

## Theorem Map

| theorem_inventory.yaml ID | Lean theorem | File |
|---------------------------|-------------|------|
| THM-NASH-PURE-EXISTENCE | `fulcrum_pure_nash_exists` | NashExistence.lean |
| THM-NONCOMPLIANT-DOMINATED | `noncompliant_strictly_dominated` | NashExistence.lean |
| THM-NASH-MIXED-EXISTENCE | `mixed_nash_exists` | MixedNashExistence.lean |
| THM-NOT-DSIC | `proportional_allocation_not_dsic` | IncentiveCompatibility.lean |
| THM-NASH-UNIQUENESS | `nash_eq_allModerate` | NashUniqueness.lean |
| THM-POA-BOUNDED | `fulcrum_poa_bounded` | CoordinationEfficiency.lean |
| THM-POA-CONSTRAINED | `constrained_poa_exact` | CoordinationEfficiency.lean |
| THM-BUDGET-GAME-BRIDGE | `budget_game_bridge` | BudgetGameBridge.lean |

## Known Gaps (0 sorry)

### ~~`mixed_nash_exists` (MixedNashExistence.lean)~~ — RESOLVED

Mixed Nash existence is now closed via math-xmum/Brouwer's `ExistsNashEq` (Brouwer fixed-point on product simplices via Scarf's Lemma) through a PMF ↔ stdSimplex bridge.

The Fulcrum-Proofs lakefile depends on a local v4.29-ported fork at `../math-xmum-brouwer-fork` (branch `fulcrum-v4.29-port`). The bridge constructions `pmfToSimplex` / `simplexToPMF` and the round-trip lemma `pmfToSimplex_simplexToPMF` translate between our PMF-based `MixedStrategyProfile` and math-xmum's `stdSimplex`-based `FinGame.mixedS`. The `kakutani_fixed_point_theorem` axiom has been removed.

### ~~`fulcrum_poa_bounded` (CoordinationEfficiency.lean)~~ — RESOLVED

Resolved via `nash_eq_allModerate` in NashUniqueness.lean (703 lines). Proves all-moderate is the unique Nash equilibrium under tight budget (25n, n ≤ 12) via 4 elimination steps: noncompliant (strictly dominated), overflow (pigeonhole + 25/n > 2), conservative (deviation gains ≥ 4), aggressive (total ≥ 25n + 25 > budget). PR #5.

### ~~`constrained_poa_exact` (CoordinationEfficiency.lean)~~ — RESOLVED

Resolved by proving the budget-feasible welfare optimum is the all-moderate welfare (`7n`) under the tight budget. The proof uses a per-action affine welfare bound plus the budget feasibility constraint, then derives constrained PoA = `1.0` from Nash uniqueness.

## Empirical PoA Note

The simulation artifact `benchmarks/raw/nash-convergence.json` computes optimal welfare under the same budgeted payoff function as the Lean model. For the audited tight-budget instance (`n=5`, `budget=125`), best-response dynamics converge to the welfare-optimal all-moderate profile, so realized PoA is `1.0`. Lean now proves the constrained tight-budget result exactly; the unconstrained reference theorem remains the general upper bound `PoA ≤ 9/7`.

## Assumptions Register

| ID | Assumption | Used By |
|----|-----------|---------|
| A-GAME-001 | Agents have exactly 4 finite actions | NashExistence, CoordinationEfficiency |
| A-GAME-002 | Budget = 25 * agentCount (tight budget) | NashExistence, CoordinationEfficiency |
| A-GAME-003 | Violation penalty (20) > quality gain from noncompliance (1) | NashExistence |
| A-GAME-004 | Finite strategy sets (Fintype) | MixedNashExistence |
| A-GAME-005 | Real-valued continuous payoffs | MixedNashExistence |
| A-MECH-001 | Proportional allocation with allocationUtility = -|allocation - trueNeed| | IncentiveCompatibility |

## Key Design Decision: Non-DSIC Result

The original plan assumed proportional allocation is DSIC (dominant-strategy incentive-compatible). Mathematical review found a counterexample: with n=2, budget=20, needs=(5,5), an agent can under-report to 5/3 and receive exactly 5 (utility 0) instead of truthfully reporting 5 and receiving 10 (utility -5). The Lean proofs now establish the **negative** result: `proportional_allocation_not_dsic` and `fulcrum_not_ic_under_sufficiency`.
