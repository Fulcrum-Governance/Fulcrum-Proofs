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
Nash   Mixed   Coord     BudgetGame
Exist  Nash    Efficiency  Bridge
  |    Exist      |
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
| THM-POA-BOUNDED | `fulcrum_poa_bounded` | CoordinationEfficiency.lean |
| THM-BUDGET-GAME-BRIDGE | `budget_game_bridge` | BudgetGameBridge.lean |

## Known Gaps (2 sorry)

### `mixed_nash_exists` (MixedNashExistence.lean)

The final Kakutani-to-mixed-Nash step is axiomatized. Both external Lean 4 repos with Kakutani FPT proofs (harfe/fixed-point-theorems-lean4, math-xmum/Brouwer) are pinned to Lean 4.21-4.22 and are incompatible with our 4.29 toolchain. Mathlib4 does not include Kakutani.

Resolution paths:
- Wait for upstream repos to upgrade toolchains
- Wait for Mathlib4 to add Brouwer/Kakutani
- Port harfe's Sperner-based proof to v4.29 manually

### `fulcrum_poa_bounded` (CoordinationEfficiency.lean)

Requires proving that under tight budget (budget = 25n) with n <= 12, every Nash equilibrium is the all-moderate profile (Nash uniqueness). The welfare helper lemmas (`allModerate_welfare`, `welfare_upper_bound`) are already sorry-free.

Resolution: prove `nash_implies_allModerate` by showing conservative, aggressive, and noncompliant are non-best-responses for every agent in any profile.

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
