---
name: game-theory-proof-engineer
description: >
  Guide writing Lean 4 game theory proofs for the Fulcrum coordination game,
  including Nash equilibrium existence, incentive compatibility, and Price of
  Anarchy bounds. Use this skill PROACTIVELY when creating or modifying any
  file under proofs/lean/Proofs/GameTheory/, when writing theorems involving
  payoff functions, strategy profiles, best responses, or mechanism design,
  or when encountering tactic failures on noncomputable real-valued definitions.
  Also use when importing from harfe/fixed-point-theorems-lean4 or
  math-xmum/Brouwer for Kakutani/Brouwer applications.
---

# Game Theory Proof Engineer

## Context

The Fulcrum-Proofs repo is building the first Lean 4 formalization of
Nash equilibrium for an AI governance system. The game models agents
competing for shared token budgets under policy enforcement. Key theorems:

- Nash equilibrium existence (pure + mixed strategy)
- Incentive compatibility (DSIC for proportional allocation)
- Price of Anarchy bound (9/7 for the Fulcrum game)
- Budget-game bridge (connecting existing budget_safety_guarantee to game model)

All existence proofs are `noncomputable` (depend on Classical.choice).
This is by design — Lean proves existence, Python computes equilibria.

## Architecture

```
proofs/lean/Proofs/GameTheory/
├── Definitions.lean              -- NormalFormGame, Nash, Pareto, PoA types
├── FulcrumGame.lean              -- AgentAction, fulcrumPayoff, fulcrumCoordinationGame
├── NashExistence.lean            -- Pure-strategy Nash for Fulcrum game
├── MixedNashExistence.lean       -- Mixed-strategy Nash via imported Kakutani
├── IncentiveCompatibility.lean   -- DSIC for proportional allocation
├── CoordinationEfficiency.lean   -- Price of Anarchy bound
└── BudgetGameBridge.lean         -- Connect budget_safety_guarantee to game model
```

Each file imports from the previous ones. `MixedNashExistence.lean` also
imports from external dependencies (harfe Kakutani, math-xmum product simplex).

## The `noncomputable` Challenge

The biggest tactic engineering challenge in this codebase is that payoff
functions are `noncomputable` (they use real-number arithmetic with
conditionals). This means:

1. `simp` and `norm_num` cannot reduce `noncomputable` definitions
2. `decide` cannot evaluate noncomputable propositions
3. You often need to unfold definitions manually and use `linarith` or `calc`

### Tactics That Work on Noncomputable ℝ Definitions

| Tactic | When to Use |
|--------|-------------|
| `unfold fulcrumPayoff` | Always start by unfolding the payoff definition |
| `simp [actionQuality, actionTokenCost, actionViolates]` | Reduce the enum-level functions (these ARE computable) |
| `norm_num` | After reducing to literal ℝ arithmetic (e.g., `(7 : ℝ) > (-12 : ℝ)`) |
| `linarith` | For linear inequalities over ℝ after unfolding |
| `ring` | For algebraic identities |
| `split_ifs` | To case-split on `if` conditions in the payoff function |
| `omega` | For Nat arithmetic (use before casting to ℝ) |
| `push_cast` | Convert between Nat and ℝ casts |
| `positivity` | Prove expressions are positive/nonneg |

### Pattern: Proving Payoff Inequalities

Most game theory proofs reduce to showing one payoff is greater than another.
The standard pattern is:

```lean
theorem example_payoff_dominance ... := by
  -- 1. Unfold the payoff definition
  unfold fulcrumPayoff
  -- 2. Simplify enum-level functions
  simp [actionQuality, actionViolates, violationPenalty, actionTokenCost]
  -- 3. Split conditionals
  split_ifs with h₁ h₂
  -- 4. Each branch reduces to ℝ arithmetic
  all_goals (push_cast; linarith)
```

If this doesn't close the goal, the issue is usually that `totalTokens`
doesn't reduce because it involves a `Finset.sum` over an abstract `Fin n`.
In that case:

```lean
-- For concrete n (e.g., n = 2):
simp [totalTokens, Finset.sum_fin_eq_sum_range]

-- For abstract n, you may need:
have h_total : totalTokens n profile = ... := by
  unfold totalTokens
  simp [Finset.sum]
  -- manual calculation
```

### Pattern: Case-Splitting on AgentAction

Nash equilibrium proofs require showing no deviation is profitable.
Since AgentAction has 4 constructors, use:

```lean
intro s'
-- Case split on the 4 possible deviations
cases s' with
| conservative => ...
| moderate => ...
| aggressive => ...
| noncompliant => ...
```

Each case then follows the payoff inequality pattern above.

## Mixed-Strategy Nash via Kakutani

The mixed-strategy proof (Task 6) threads together three libraries.
The proof structure is:

```
1. Construct the product simplex
   - Each player's mixed strategy lives in a probability simplex
   - Product of n simplices forms the joint strategy space
   - Use math-xmum/Brouwer's product simplex infrastructure

2. Define the best-response correspondence
   - For each player i and opponents' mixed profile σ₋ᵢ
   - BR_i(σ₋ᵢ) = argmax_{σ_i} E[payoff_i(σ_i, σ₋ᵢ)]
   - This is a set-valued map (correspondence)

3. Show Kakutani hypotheses hold
   - Domain is compact convex (product of simplices) ✓
   - BR is upper hemicontinuous (follows from payoff continuity)
   - BR values are nonempty (max over compact set)
   - BR values are convex (expected payoff is linear in own σ_i)

4. Apply Kakutani → get fixed point
   - Import from harfe/fixed-point-theorems-lean4

5. Fixed point = Nash equilibrium
   - By definition of best response
```

The hardest sub-step is proving upper hemicontinuity of the best-response
correspondence. This requires showing that the expected payoff function is
continuous in the mixed strategy profile, which follows from the finite
sum structure but requires careful Mathlib manipulation.

If this proves too difficult, a viable fallback is to prove Nash existence
for the specific Fulcrum game (4 actions, n players) by exhaustive
construction, avoiding the general Kakutani path entirely.

## Incentive Compatibility Proof Strategy

The DSIC proof for proportional allocation proceeds by showing:

For agent i with true need `n_i` and total reported need `T`:
- Truthful allocation: `n_i * B / T`
- Inflated report `n_i + k`: allocation = `(n_i + k) * B / (T + k)`

Need to show: `n_i / T >= (n_i + k) / (T + k)` for k > 0, T > n_i.

Cross-multiply: `n_i * (T + k) >= (n_i + k) * T`
Expand: `n_i * T + n_i * k >= n_i * T + k * T`
Simplify: `n_i * k >= k * T`
Since k > 0: `n_i >= T`

This is FALSE when T > n_i (other agents also report needs). So the
proportional mechanism is NOT DSIC in general — it's only IC when
budget is sufficient for all truthful reports (no competition).

The theorem must be stated with the sufficiency assumption:
`hSufficient : ∀ types, Σ needs_i <= budget`

Under sufficiency, each agent gets exactly what they request when truthful,
so inflating provides no benefit (you already get everything you need).

## Connecting to Existing Proofs

The `BudgetGameBridge.lean` file connects to `BasicInvariants.lean`:

```lean
-- This theorem already exists:
theorem budget_safety_guarantee (b a newB) (hExec) :
  newB.currentSpent <= newB.aggregateLimit

-- The bridge shows this GROUNDS the game:
-- Agents cannot execute actions that exceed budget,
-- so the game's withinBudget predicate is enforced by runtime.
-- This eliminates "cheating" from the strategy space.
```

The bridge proof is straightforward — it just applies the existing theorem
in the game-theoretic context. The conceptual value is making the connection
explicit and auditable.

## Quality Checklist

Before committing any game theory proof file:

- [ ] No `sorry` anywhere in the file
- [ ] `lake build Proofs.GameTheory.<Module>` succeeds
- [ ] `./proofs/lean/scripts/check_no_sorry.sh` passes
- [ ] All assumptions are documented in `claims/theorem_inventory.yaml`
- [ ] Theorem names follow the convention: `thm_<property>` for inventory theorems,
      descriptive names for supporting lemmas
- [ ] `noncomputable` tag is present where needed (Lean enforces this)
- [ ] No `set_option maxHeartbeats` unless absolutely necessary (document why)
