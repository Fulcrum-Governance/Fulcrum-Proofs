# Game Theory Proof Layer

Lean 4 + Mathlib4 formalization of Fulcrum's multi-agent coordination mechanism.

## Canonical Exact Dependency Graph

```text
FulcrumGame
     |
ExactDefinitions
     |
ExactSumUpdateLemmas
     |
ExactNashExistence
     |
ExactNashUniqueness
     |
CoordinationEfficiencyExact
     |
constrained_poa_exact  [propext]

CoordinationEfficiencyExact ---> CoordinationEfficiency (legacy Real compat)
                \------------> CoordinationCorrespondence <--- Real model
```

`CoordinationCorrespondence.lean` is deliberately downstream. No Real bridge
theorem enters the canonical declaration's dependency closure.

## Theorem Map

| theorem_inventory.yaml ID | Lean theorem | File |
|---------------------------|-------------|------|
| THM-NASH-PURE-EXISTENCE | `fulcrum_pure_nash_exists` | NashExistence.lean |
| THM-NONCOMPLIANT-DOMINATED | `noncompliant_strictly_dominated` | NashExistence.lean |
| THM-NASH-MIXED-EXISTENCE | `mixed_nash_exists` | MixedNashExistence.lean |
| THM-NOT-DSIC | `proportional_allocation_not_dsic` | IncentiveCompatibility.lean |
| THM-NASH-UNIQUENESS | `nash_eq_allModerate` | NashUniqueness.lean |
| THM-POA-BOUNDED | `fulcrum_poa_bounded` | CoordinationEfficiency.lean |
| THM-NASH-PURE-EXISTENCE-EXACT | `exactAllModerate_isNash` | ExactNashExistence.lean |
| THM-NASH-UNIQUENESS-EXACT | `exactNash_eq_allModerate` | ExactNashUniqueness.lean |
| THM-POA-CONSTRAINED | `constrained_poa_exact` | CoordinationEfficiencyExact.lean |
| THM-POA-CONSTRAINED-REAL-COMPAT | `constrained_poa_exact_real_compat` | CoordinationEfficiency.lean |
| THM-POA-CONSTRAINED-CORRESPONDENCE | `exactFullClaim_iff_realFullClaim` | CoordinationCorrespondence.lean |
| THM-BUDGET-GAME-BRIDGE | `budget_game_bridge` | BudgetGameBridge.lean |

## Module Table

| File | Role |
|------|------|
| ExactDefinitions.lean | Exact signed-Nat values/order, structural roster, payoff, Nash, welfare, and PoA surfaces |
| ExactSumUpdateLemmas.lean | Kernel-1 structural sum, lookup, roster, count, and update identities |
| ExactNashExistence.lean | Exact all-moderate value and Nash existence |
| ExactNashUniqueness.lean | Structural exclusion/uniqueness for every positive `agentCount` in 1..12 |
| CoordinationEfficiencyExact.lean | Feasibility, exact `7*n` attainment, optimality, and canonical six-clause PoA theorem |
| CoordinationEfficiency.lean | Legacy Real theorem retained as noncanonical compatibility/provenance evidence |
| CoordinationCorrespondence.lean | Fourteen named exact/Real correspondence obligation families |

## Known Gaps (0 sorry)

### ~~`mixed_nash_exists` (MixedNashExistence.lean)~~ — RESOLVED

Mixed Nash existence is now closed via math-xmum/Brouwer's `ExistsNashEq` (Brouwer fixed-point on product simplices via Scarf's Lemma) through a PMF ↔ stdSimplex bridge.

The Fulcrum-Proofs lakefile depends on a local v4.29-ported fork at `../math-xmum-brouwer-fork` (branch `fulcrum-v4.29-port`). The bridge constructions `pmfToSimplex` / `simplexToPMF` and the round-trip lemma `pmfToSimplex_simplexToPMF` translate between our PMF-based `MixedStrategyProfile` and math-xmum's `stdSimplex`-based `FinGame.mixedS`. The `kakutani_fixed_point_theorem` axiom has been removed.

### ~~`fulcrum_poa_bounded` (CoordinationEfficiency.lean)~~ — RESOLVED

Resolved via `nash_eq_allModerate` in NashUniqueness.lean (703 lines). Proves all-moderate is the unique Nash equilibrium under tight budget (25n, n ≤ 12) via 4 elimination steps: noncompliant (strictly dominated), overflow (pigeonhole + 25/n > 2), conservative (deviation gains ≥ 4), aggressive (total ≥ 25n + 25 > budget). PR #5.

### `constrained_poa_exact` canonical migration — RESOLVED

The canonical declaration is now the exact-data `ExactFullClaim` in
`CoordinationEfficiencyExact.lean`, measured exactly `[propext]`. It explicitly
contains all-moderate Nash existence, pointwise uniqueness of every pure Nash
profile, feasibility, exact `7*n` attainment (numerator `7*n*n`), welfare
optimality over every feasible profile, and every Nash/feasible relational PoA
comparison at exactly one. It covers every existing positive `BudgetParams`
with `B=25*n` and `n≤12`, including `n=1`.

The previous Real theorem is `constrained_poa_exact_real_compat` at kernel-3.
The integer theorem remains an additive welfare-only companion with no Nash
quantifier.

## Correspondence Obligations

`CoordinationCorrespondence.lean` exposes each required family through named
declarations:

1. exact action cost/quality/violation/penalty identities;
2. `correspondenceRoster_length` and `correspondenceRoster_get`;
3. `structuralSum_eq_finsetSum` and `exactTotalTokens_eq_totalTokens`;
4. `signedNatValue_add` and `signedNat_le_iff_real_le`;
5. `exactPayoff_value`, `exactPayoff_value_noOverflow`, and `exactPayoff_value_overflow`;
6. `exactPayoff_le_iff_realPayoff_le`;
7. exact/update changed/unchanged identities;
8. `exactWithinBudget_iff_withinBudget`;
9. `exactIsNash_iff_isNashEquilibrium`;
10. exact welfare value and bidirectional order identities;
11. named all-moderate profile, cost, feasibility, payoff, and welfare identities;
12. all-moderate Nash existence and pointwise uniqueness correspondence;
13. `exactFullClaim_iff_realFullClaim`, including explicit `7*n` attainment;
14. `exactCompleteDomain_iff_realCompleteDomain` over the complete positive `1..12` domain.

## Empirical PoA Note

The simulation artifact `benchmarks/raw/nash-convergence.json` computes optimal welfare under the same budgeted payoff function as the Lean model. For the audited tight-budget instance (`n=5`, `budget=125`), best-response dynamics converge to the welfare-optimal all-moderate profile, so realized PoA is `1.0`. The exhaustive count-equivalence artifact separately covers `n=2..12`. Neither empirical range narrows the formal exact theorem's positive `1..12` domain. The unconstrained reference theorem remains the general upper bound `PoA ≤ 9/7`.

## Assumptions Register

| ID | Assumption | Used By |
|----|-----------|---------|
| A-GAME-001 | Agents have exactly 4 finite actions | NashExistence, CoordinationEfficiency |
| A-GAME-002 | Budget = 25 * agentCount (tight budget) | NashExistence, CoordinationEfficiency |
| A-GAME-003 | Violation penalty (20) > quality gain from noncompliance (1) | NashExistence |
| A-GAME-004 | Finite strategy sets (Fintype) | MixedNashExistence |
| A-GAME-005 | Real-valued continuous payoffs | MixedNashExistence |
| A-GAME-006 | positive agentCount in range 1..12 | ExactNashExistence, ExactNashUniqueness, CoordinationEfficiencyExact, Real compatibility |
| A-MECH-001 | Proportional allocation with allocationUtility = -|allocation - trueNeed| | IncentiveCompatibility |

## Key Design Decision: Non-DSIC Result

The original plan assumed proportional allocation is DSIC (dominant-strategy incentive-compatible). Mathematical review found a counterexample: with n=2, budget=20, needs=(5,5), an agent can under-report to 5/3 and receive exactly 5 (utility 0) instead of truthfully reporting 5 and receiving 10 (utility -5). The Lean proofs now establish the **negative** result: `proportional_allocation_not_dsic` and `fulcrum_not_ic_under_sufficiency`.
