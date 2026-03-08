> **Status: Executed with deviations** (2026-03-08). Final result: **16 to 2 sorry**
> (not 16 to 1 as originally targeted). Deviations:
> - IC theorems (Tasks 7): The positive DSIC claim was mathematically false.
>   All 3 IC sorry holes were closed by proving the **negative** result (not DSIC)
>   via a two-agent counterexample, rather than the original false positive.
> - PoA (Task 6): `fulcrum_poa_bounded` retains 1 sorry because the Nash uniqueness
>   lemma required for the final step was deferred. Welfare helper lemmas are sorry-free.
> - Mixed Nash (Task 8): `mixed_nash_exists` retains 1 sorry (Kakutani gap, as expected).

# Sorry Hole Closure Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close 15 of 16 sorry holes in the game theory Lean proofs, reducing sorry count from 16 to 1.

**Architecture:** The root cause of 10/16 sorry holes is a single pattern: `Finset.sum` over a composed `Function.update`. The Mathlib4 lemma `Finset.add_sum_erase` + `Function.update_same` + `Function.update_noteq` provides a 7-line tactic sequence that handles all cases. The remaining sorry holes are real arithmetic (IC proofs), constant-function sums (welfare), and a witness construction (bridge). The one uncloseable sorry is `mixed_nash_exists` — blocked by Kakutani FPT axiomatization (both external repos stuck at Lean v4.21-4.22, no Kakutani in Mathlib4).

**Tech Stack:** Lean 4.29.0-rc4, Mathlib4 (BigOperators, Fintype, Real, PMF)

---

## Sorry Inventory (16 total)

| # | File | Line | Sorry | Root Cause | Closeable? |
|---|------|------|-------|------------|------------|
| 1 | NashExistence.lean | 54 | `totalTokens_deviation` | Finset.sum + Function.update | YES |
| 2 | NashExistence.lean | 71 | `noncompliant_strictly_dominated` | Finset.sum + payoff comparison | YES |
| 3 | NashExistence.lean | 85 | `allModerate_payoff_eq_seven` | Unfold payoff + arithmetic | YES |
| 4 | NashExistence.lean | 120 | moderate case | Function.update_eq_self | YES |
| 5 | NashExistence.lean | 124 | conservative case | totalTokens + arithmetic | YES |
| 6 | NashExistence.lean | 128 | aggressive case | totalTokens + cast + linarith | YES |
| 7 | NashExistence.lean | 132 | noncompliant case | totalTokens + penalty arithmetic | YES |
| 8 | CoordinationEfficiency.lean | 28 | `allModerate_welfare` | Constant sum = 7n | YES |
| 9 | CoordinationEfficiency.lean | 35 | `welfare_upper_bound` | Per-agent payoff ≤ 9 | YES |
| 10 | CoordinationEfficiency.lean | 48 | `fulcrum_poa_bounded` | Welfare bounds → PoA | YES |
| 11 | IncentiveCompatibility.lean | 69 | `truthful_allocation_sufficient` | Real division arithmetic | YES |
| 12 | IncentiveCompatibility.lean | 92 | `proportional_allocation_dsic` | IsDSIC witness from #11 | YES |
| 13 | IncentiveCompatibility.lean | 104 | `fulcrum_ic_under_sufficiency` | Corollary of #12 | YES |
| 14 | MixedNashExistence.lean | 62 | `expectedPayoff` definition | Definition body needs impl | YES |
| 15 | MixedNashExistence.lean | 98 | `mixed_nash_exists` | Kakutani axiom connection | **NO** |
| 16 | BudgetGameBridge.lean | 78 | `budget_game_bridge` | Witness + needs hSmall | YES |

**Target: 16 → 1 sorry** (only `mixed_nash_exists` remains)

---

## Phase 1: Core Helper Lemmas

### Task 1: Add imports and prove Finset.sum + Function.update helpers

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/SumUpdateLemmas.lean`
- Modify: `proofs/lean/Proofs.lean` (add import)

These helper lemmas are the foundation for 10 of 16 sorry closures. The key tactic pattern comes from Gemini Deep Research: use `Finset.add_sum_erase` to pull out the updated index, then `Function.update_same` / `Function.update_noteq` to simplify.

**Step 1: Create the helper lemma file**

```lean
/-
  Helper lemmas for Finset.sum with Function.update composition.

  The core pattern: when summing f ∘ (Function.update g i a) over Fin n,
  pull out index i using add_sum_erase, simplify with update_same/update_noteq.

  These unlock 10 of 16 sorry holes in the game theory proofs.
-/

import Proofs.GameTheory.FulcrumGame
import Mathlib.Algebra.BigOperators.Group.Finset

set_option autoImplicit false

open scoped BigOperators

namespace Fulcrum.GameTheory

/-- When summing a composed function over a Function.update, the result
    splits into f(new_value) + sum of f(old_values) for other indices.
    This is the fundamental lemma for all payoff deviation proofs. -/
lemma sum_comp_update {n : Nat} (i : Fin n) (a : α) (f : α → Nat) (g : Fin n → α) :
    (∑ j : Fin n, f (Function.update g i a j)) =
    f a + ∑ j ∈ Finset.univ.erase i, f (g j) := by
  rw [← Finset.add_sum_erase Finset.univ _ (Finset.mem_univ i)]
  rw [Function.update_same]
  congr 1
  apply Finset.sum_congr rfl
  intro j hj
  rw [Finset.mem_erase] at hj
  rw [Function.update_noteq hj.1]

/-- Specialization: sum of actionTokenCost over an updated all-moderate profile. -/
lemma totalTokens_update_allModerate (n : Nat) (i : Fin n) (a : AgentAction) :
    totalTokens n (Function.update (fun _ => AgentAction.moderate) i a) =
    actionTokenCost a + 25 * (n - 1) := by
  unfold totalTokens
  rw [sum_comp_update i a actionTokenCost _]
  congr 1
  -- The remaining sum is ∑ j ∈ univ.erase i, actionTokenCost moderate = 25 * (n-1)
  simp only [actionTokenCost]
  rw [Finset.sum_const, Finset.card_erase_of_mem (Finset.mem_univ i),
      Finset.card_univ, Fintype.card_fin]
  ring

/-- General version: totalTokens changes predictably under any single-agent update. -/
lemma totalTokens_update_general (n : Nat) (profile : Fin n → AgentAction)
    (i : Fin n) (a : AgentAction) :
    (totalTokens n (Function.update profile i a) : ℤ) =
    (totalTokens n profile : ℤ) - (actionTokenCost (profile i) : ℤ) +
    (actionTokenCost a : ℤ) := by
  unfold totalTokens
  rw [sum_comp_update i a actionTokenCost profile]
  rw [← Finset.add_sum_erase Finset.univ (fun j => actionTokenCost (profile j))
      (Finset.mem_univ i)]
  push_cast
  ring

/-- The sum of a constant ℝ-valued function over Fin n equals c * n. -/
lemma sum_const_real (n : Nat) (c : ℝ) :
    (∑ _ : Fin n, c) = c * n := by
  simp [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]

end Fulcrum.GameTheory
```

**Step 2: Add import to root module**

In `proofs/lean/Proofs.lean`, add before the NashExistence import:
```
import Proofs.GameTheory.SumUpdateLemmas
```

**Step 3: Build and verify**

Run: `cd proofs/lean && lake build Proofs.GameTheory.SumUpdateLemmas 2>&1 | tail -20`
Expected: Build succeeds with no errors (no sorry in this file).

**Step 4: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/SumUpdateLemmas.lean proofs/lean/Proofs.lean
git commit -m "feat(proofs): add Finset.sum + Function.update helper lemmas (sorry-free)"
```

---

## Phase 2: Close NashExistence.lean (7 sorry → 0)

### Task 2: Close totalTokens_deviation

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/NashExistence.lean:48-54`

**Step 1: Replace the sorry**

Replace the `totalTokens_deviation` lemma body:

```lean
lemma totalTokens_deviation (n : Nat) (i : Fin n) (a : AgentAction) :
    totalTokens n (Function.update (allModerate n) i a) =
    25 * n - 25 + actionTokenCost a := by
  unfold allModerate
  rw [totalTokens_update_allModerate]
  omega
```

The `totalTokens_update_allModerate` helper gives us `actionTokenCost a + 25 * (n - 1)`.
`omega` closes `actionTokenCost a + 25 * (n - 1) = 25 * n - 25 + actionTokenCost a` (Nat arithmetic).

**Step 2: Build**

Run: `cd proofs/lean && lake build Proofs.GameTheory.NashExistence 2>&1 | grep -E "(error|sorry)" | head -20`
Expected: 6 remaining sorry warnings (down from 7), no errors.

### Task 3: Close allModerate_payoff_eq_seven

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/NashExistence.lean:79-85`

**Step 1: Replace the sorry**

```lean
lemma allModerate_payoff_eq_seven (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (i : Fin params.agentCount) :
    fulcrumPayoff params (allModerate params.agentCount) i = 7 := by
  unfold fulcrumPayoff allModerate actionQuality actionViolates violationPenalty
  simp only []
  rw [allModerate_totalTokens]
  -- totalTokens = 25n = budget, so no overflow (if branch is false)
  simp only [hBudget, Nat.cast_mul, Nat.cast_ofNat]
  -- The condition (25 * n : ℝ) > (25 * n : ℝ) is false
  norm_num
```

If `norm_num` doesn't close it, try:
```lean
  simp [not_lt.mpr (le_refl _)]
  ring
```

**Step 2: Build and check** — 5 sorry warnings expected.

### Task 4: Close moderate_is_nash_equilibrium (4 cases)

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/NashExistence.lean:101-132`

This is the most complex closure. Each deviation case requires showing `7 ≥ payoff(deviation)`.

**Step 1: Close the moderate case (line 120)**

```lean
  | moderate =>
    show (7 : ℝ) ≥ fulcrumPayoff params (Function.update (fun _ => AgentAction.moderate) i AgentAction.moderate) i
    -- Function.update with same value is identity
    have : Function.update (fun (_ : Fin params.agentCount) => AgentAction.moderate) i AgentAction.moderate =
           fun _ => AgentAction.moderate := by
      ext j; simp [Function.update_apply]
    rw [this, ← h_base]
```

Alternative simpler approach:
```lean
  | moderate =>
    show (7 : ℝ) ≥ fulcrumPayoff params (Function.update (fun _ => AgentAction.moderate) i AgentAction.moderate) i
    simp only [Function.update_eq_self]
    linarith [h_base]
```

**Step 2: Close the conservative case (line 124)**

The deviation to conservative reduces tokens by 15 (no overflow), quality drops to 3.

```lean
  | conservative =>
    unfold fulcrumPayoff actionQuality actionViolates violationPenalty
    simp only []
    -- totalTokens after deviation: 10 + 25*(n-1) = 25n - 15
    have h_tokens := totalTokens_update_allModerate params.agentCount i AgentAction.conservative
    simp only [actionTokenCost] at h_tokens
    -- 25n - 15 ≤ 25n = budget, so no overflow
    rw [show totalTokens params.agentCount (Function.update (fun _ => AgentAction.moderate) i AgentAction.conservative) = 10 + 25 * (params.agentCount - 1) from h_tokens]
    simp only [Nat.cast_add, Nat.cast_mul, Nat.cast_ofNat]
    -- No overflow: 10 + 25*(n-1) ≤ 25*n
    have hNoOverflow : (10 + 25 * (params.agentCount - 1) : ℝ) ≤ (params.totalBudget : ℝ) := by
      rw [hBudget]; push_cast; omega
    simp [show ¬((10 + 25 * (↑(params.agentCount) - 1) : ℝ) > (↑params.totalBudget : ℝ)) from not_lt.mpr hNoOverflow]
    -- payoff = 3 - 0 - 0 = 3 ≤ 7
    linarith
```

**Step 3: Close the aggressive case (line 128)**

Aggressive adds 25 tokens overflow. Payoff = 9 - 25/n. For n ≤ 12, 25/n > 2, so 9 - 25/n < 7.

```lean
  | aggressive =>
    unfold fulcrumPayoff actionQuality actionViolates violationPenalty
    simp only []
    have h_tokens := totalTokens_update_allModerate params.agentCount i AgentAction.aggressive
    simp only [actionTokenCost] at h_tokens
    -- totalTokens = 50 + 25*(n-1) = 25n + 25 > 25n = budget
    rw [show totalTokens params.agentCount (Function.update (fun _ => AgentAction.moderate) i AgentAction.aggressive) = 50 + 25 * (params.agentCount - 1) from h_tokens]
    rw [hBudget]
    push_cast
    -- overflow = 25/n, payoff = 9 - 25/n
    -- For n ≤ 12 and n ≥ 1: 25/n ≥ 25/12 > 2, so 9 - 25/n < 7
    have hn_pos : (0 : ℝ) < params.agentCount := by exact_mod_cast params.hPositive
    have hn_le : (params.agentCount : ℝ) ≤ 12 := by exact_mod_cast hSmall
    -- The if condition: 50 + 25*(n-1) > 25*n ↔ 25 > 0 (true)
    simp only [show (50 + 25 * ((params.agentCount : ℝ) - 1)) > 25 * params.agentCount from by nlinarith]
    -- Goal reduces to: 7 ≥ 9 - (50 + 25*(n-1) - 25*n) / n = 9 - 25/n
    nlinarith [div_le_div_of_nonneg_left (by linarith : (0:ℝ) < 25) hn_pos (by linarith : (0:ℝ) < 12)]
```

Note: The exact tactic sequence may need iteration. The core mathematical argument is: `9 - 25/n ≤ 9 - 25/12 < 7`. Key tools: `push_cast`, `nlinarith`, `field_simp`.

**Step 4: Close the noncompliant case (line 132)**

Noncompliant: penalty 20, overflow 15/n. Payoff = 8 - 20 - 15/n = -12 - 15/n ≪ 7.

```lean
  | noncompliant =>
    unfold fulcrumPayoff actionQuality actionViolates violationPenalty
    simp only []
    have h_tokens := totalTokens_update_allModerate params.agentCount i AgentAction.noncompliant
    simp only [actionTokenCost] at h_tokens
    -- totalTokens = 40 + 25*(n-1) = 25n + 15 > budget
    rw [show totalTokens params.agentCount (Function.update (fun _ => AgentAction.moderate) i AgentAction.noncompliant) = 40 + 25 * (params.agentCount - 1) from h_tokens]
    rw [hBudget]
    push_cast
    have hn_pos : (0 : ℝ) < params.agentCount := by exact_mod_cast params.hPositive
    -- if condition: 40 + 25*(n-1) > 25*n ↔ 15 > 0 (true)
    simp only [show (40 + 25 * ((params.agentCount : ℝ) - 1)) > 25 * params.agentCount from by nlinarith]
    -- payoff = 8 - 20 - 15/n = -12 - 15/n < 7
    nlinarith [div_nonneg (by linarith : (0:ℝ) ≤ 15) (le_of_lt hn_pos)]
```

**Step 5: Build full file**

Run: `cd proofs/lean && lake build Proofs.GameTheory.NashExistence 2>&1 | grep -E "(error|sorry)" | head -20`
Expected: 1 remaining sorry (noncompliant_strictly_dominated), or 0 if we also close that.

### Task 5: Close noncompliant_strictly_dominated

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/NashExistence.lean:64-71`

This uses the general `totalTokens_update_general` (ℤ version) to show switching from noncompliant to moderate reduces total spend by 15 tokens, drops penalty by 20, loses 1 quality point — net gain ≥ 19.

```lean
theorem noncompliant_strictly_dominated
    (params : BudgetParams)
    (i : Fin params.agentCount) :
    ∀ profile : Fin params.agentCount → AgentAction,
    profile i = AgentAction.noncompliant →
    fulcrumPayoff params (Function.update profile i AgentAction.moderate) i
      > fulcrumPayoff params profile i := by
  intro profile hNoncomp
  unfold fulcrumPayoff
  simp only [Function.update_self_apply, hNoncomp, actionQuality, actionViolates, violationPenalty]
  -- LHS: 7 - 0 - overflow_moderate, RHS: 8 - 20 - overflow_noncompliant
  -- Need: 7 - overflow_mod > -12 - overflow_noncomp
  -- Since switching to moderate reduces total by 15, overflow_mod ≤ overflow_noncomp
  have h_cost_diff := totalTokens_update_general params.agentCount profile i AgentAction.moderate
  simp only [hNoncomp, actionTokenCost] at h_cost_diff
  -- Total tokens drops by 15 (40 → 25), so overflow decreases or stays 0
  -- The net gain from penalty removal (20) minus quality loss (1) = 19, minus any overflow improvement
  push_cast
  -- Close with nlinarith using the token difference
  nlinarith [div_nonneg (by linarith : (0:ℝ) ≤ 15)
             (by exact_mod_cast params.hPositive : (0:ℝ) < params.agentCount)]
```

**Step: Build and verify 0 sorry in NashExistence.lean**

Run: `cd proofs/lean && lake build Proofs.GameTheory.NashExistence 2>&1 | grep sorry`
Expected: No sorry warnings.

**Step: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/NashExistence.lean
git commit -m "feat(proofs): close all 7 sorry holes in NashExistence.lean"
```

---

## Phase 3: Close CoordinationEfficiency.lean (3 sorry → 0)

### Task 6: Close welfare and PoA theorems

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/CoordinationEfficiency.lean`

**Step 1: Close allModerate_welfare (line 28)**

Welfare = ∑ payoff_i = ∑ 7 = 7n.

```lean
theorem allModerate_welfare (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    socialWelfare (fulcrumCoordinationGame params)
      (fun _ => AgentAction.moderate) = 7 * params.agentCount := by
  unfold socialWelfare fulcrumCoordinationGame
  simp only []
  -- Each payoff = 7 (from allModerate_payoff_eq_seven, but need to inline here)
  -- The sum of n copies of 7 = 7n
  have : ∀ i : Fin params.agentCount,
    fulcrumPayoff params (fun _ => AgentAction.moderate) i = 7 := by
    intro i
    exact allModerate_payoff_eq_seven params hBudget i
  simp_rw [this]
  rw [sum_const_real]
```

**Step 2: Close welfare_upper_bound (line 35)**

Each payoff ≤ quality ≤ 9 (since penalty ≥ 0 and overflow ≥ 0).

```lean
theorem welfare_upper_bound (params : BudgetParams) :
    ∀ σ : StrategyProfile (fulcrumCoordinationGame params),
    socialWelfare (fulcrumCoordinationGame params) σ ≤ 9 * params.agentCount := by
  intro σ
  unfold socialWelfare fulcrumCoordinationGame
  simp only []
  calc ∑ i : Fin params.agentCount, fulcrumPayoff params (fun j => σ j) i
      ≤ ∑ i : Fin params.agentCount, (9 : ℝ) := by
        apply Finset.sum_le_sum
        intro i _
        unfold fulcrumPayoff actionQuality actionViolates violationPenalty
        -- payoff = quality - penalty - overflow ≤ quality ≤ 9
        have hq : (actionQuality (σ i) : ℝ) ≤ 9 := by
          cases σ i <;> simp [actionQuality] <;> norm_num
        linarith [div_nonneg (by positivity) (by exact_mod_cast params.hPositive : (0:ℝ) < params.agentCount)]
    _ = 9 * params.agentCount := by rw [sum_const_real]
```

**Step 3: Close fulcrum_poa_bounded (line 48)**

PoA ≤ 9/7: for any Nash σ_eq, welfare(σ_opt) ≤ 9n ≤ (9/7) * 7n ≤ (9/7) * welfare(σ_eq).

Under tight budget + n ≤ 12, allModerate is the unique Nash (proved by showing every other action is a non-best-response). We need a helper lemma for this, or we can directly argue that any Nash eq has welfare ≥ 7n.

The simplest approach: show that in any Nash eq under tight budget + n ≤ 12, each agent's payoff ≥ 7 (since they could deviate to moderate for payoff 7 under allModerate conditions, and Nash means they're at least as well off).

Actually, the cleanest proof: since `moderate_is_nash_equilibrium` shows allModerate is Nash with welfare 7n, and `welfare_upper_bound` shows any profile has welfare ≤ 9n, we need: for any Nash σ_eq, (9/7) * welfare(σ_eq) ≥ 9n, i.e., welfare(σ_eq) ≥ 7n.

**Helper approach:** Prove that under tight budget + n ≤ 12, all Nash equilibria have welfare = 7n (because allModerate is the unique Nash). This requires showing no agent plays conservative (can improve by switching to moderate) and no agent plays aggressive (overflow > quality gain for n ≤ 12). We add this as a helper lemma:

```lean
/-- Under tight budget + n ≤ 12, every Nash equilibrium agent plays moderate. -/
lemma nash_implies_allModerate (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12)
    (σ : StrategyProfile (fulcrumCoordinationGame params))
    (hNash : IsNashEquilibrium (fulcrumCoordinationGame params) σ) :
    ∀ i, σ i = AgentAction.moderate := by
  sorry -- Prove by showing conservative/aggressive/noncompliant are non-best-responses
```

If proving Nash uniqueness is too complex for this pass, the alternative is to weaken the PoA bound to reference the specific allModerate equilibrium:

```lean
theorem fulcrum_poa_bounded (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    PriceOfAnarchyBounded (fulcrumCoordinationGame params) (9 / 7) := by
  intro σ_eq hNash σ_opt
  have h_upper := welfare_upper_bound params σ_opt
  -- Need: welfare(σ_eq) ≥ 7n, then (9/7) * 7n = 9n ≥ welfare(σ_opt)
  have h_eq_mod : ∀ i, σ_eq i = AgentAction.moderate :=
    nash_implies_allModerate params hBudget hSmall σ_eq hNash
  have h_lower : socialWelfare (fulcrumCoordinationGame params) σ_eq = 7 * params.agentCount := by
    have : σ_eq = fun _ => AgentAction.moderate := funext h_eq_mod
    rw [this]
    exact allModerate_welfare params hBudget
  linarith [h_lower, h_upper, params.hPositive]
```

**NOTE:** The `nash_implies_allModerate` lemma may itself need sorry if the proof is too complex. In that case, we replace the 3 sorry in CoordinationEfficiency with 1 sorry in `nash_implies_allModerate` — still a net reduction.

**Step 4: Build and verify**

Run: `cd proofs/lean && lake build Proofs.GameTheory.CoordinationEfficiency 2>&1 | grep sorry`

**Step 5: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/CoordinationEfficiency.lean proofs/lean/Proofs/GameTheory/SumUpdateLemmas.lean
git commit -m "feat(proofs): close welfare and PoA bound sorry holes"
```

---

## Phase 4: Close IncentiveCompatibility.lean (3 sorry → 0)

### Task 7: Close DSIC proofs

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/IncentiveCompatibility.lean`

**Step 1: Close truthful_allocation_sufficient (line 69)**

Under budget sufficiency, `budget ≥ totalReported` and each need > 0.
So `budget * need_i / totalReported ≥ need_i` because `budget / totalReported ≥ 1`.

```lean
theorem truthful_allocation_sufficient
    {n : Nat} (budget : ℝ) (trueNeeds : Fin n → BudgetRequest)
    (hSuff : BudgetSufficient budget trueNeeds)
    (hBudgetPos : budget > 0) (hn : n > 0) (i : Fin n) :
    proportionalAllocation budget trueNeeds i ≥ (trueNeeds i).amount := by
  unfold proportionalAllocation
  set total := Finset.sum Finset.univ (fun j => (trueNeeds j).amount)
  have hTotalPos : total > 0 := by
    apply Finset.sum_pos
    · intro j _; exact (trueNeeds j).hPositive
    · exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩
  simp only [show total > 0 from hTotalPos, ↓reduceIte]
  -- Goal: budget * need_i / total ≥ need_i
  rw [ge_iff_le, div_le_iff hTotalPos |>.symm |>.mp]
  -- Goal: need_i * total ≤ budget * need_i
  have hNeedPos := (trueNeeds i).hPositive
  unfold BudgetSufficient at hSuff
  nlinarith
```

**Step 2: Close proportional_allocation_dsic (line 92)**

DSIC: truthful reporting maximizes utility for every agent.

```lean
theorem proportional_allocation_dsic
    {n : Nat} (budget : ℝ) (trueNeeds : Fin n → BudgetRequest)
    (hSuff : BudgetSufficient budget trueNeeds)
    (hBudgetPos : budget > 0) (hn : n > 0) :
    IsDSIC
      (mechanism := fun (reports : (i : Fin n) → BudgetRequest) =>
        fun i => proportionalAllocation budget reports i)
      (utility := fun i trueNeed_i outcome =>
        allocationUtility trueNeed_i.amount (outcome i)) := by
  intro i types t'_i
  unfold allocationUtility
  -- Need: -|truthful_alloc - need| ≥ -|deviated_alloc - need|
  -- i.e., |deviated_alloc - need| ≥ |truthful_alloc - need|
  -- Under sufficiency: truthful_alloc ≥ need, so |truthful_alloc - need| = truthful_alloc - need
  -- Key: truthful reporting gives allocation ≥ need (from truthful_allocation_sufficient)
  have h_suff := truthful_allocation_sufficient budget trueNeeds hSuff hBudgetPos hn i
  -- The truthful allocation satisfies need, so deviation can only make things worse
  linarith [abs_nonneg (proportionalAllocation budget (Function.update types i t'_i) i - (types i).amount),
            abs_nonneg (proportionalAllocation budget types i - (types i).amount)]
```

Note: This proof sketch may need refinement. The core argument is that under sufficiency, truthful allocation ≥ need, giving |alloc - need| = alloc - need, which is minimized at the truthful report. If `linarith` doesn't close it, use `abs_sub_abs_le_abs_sub` or manual case splitting on the absolute values.

**Step 3: Close fulcrum_ic_under_sufficiency (line 104)**

```lean
theorem fulcrum_ic_under_sufficiency
    {n : Nat} (budget : ℝ) (trueNeeds : Fin n → BudgetRequest)
    (hSuff : BudgetSufficient budget trueNeeds)
    (hBudgetPos : budget > 0) (hn : n > 0) :
    ∀ (i : Fin n) (falseReport : BudgetRequest),
    allocationUtility (trueNeeds i).amount (proportionalAllocation budget trueNeeds i) ≥
    allocationUtility (trueNeeds i).amount
      (proportionalAllocation budget (Function.update trueNeeds i falseReport) i) := by
  intro i falseReport
  exact proportional_allocation_dsic budget trueNeeds hSuff hBudgetPos hn i trueNeeds falseReport
```

This is a direct application of the DSIC theorem with `types = trueNeeds` and `t'_i = falseReport`.

**Step 4: Build and verify**

Run: `cd proofs/lean && lake build Proofs.GameTheory.IncentiveCompatibility 2>&1 | grep sorry`

**Step 5: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/IncentiveCompatibility.lean
git commit -m "feat(proofs): close DSIC incentive compatibility sorry holes"
```

---

## Phase 5: Fix expectedPayoff Definition + Close BudgetGameBridge

### Task 8: Replace expectedPayoff sorry with proper definition

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/MixedNashExistence.lean:60-62`

The `expectedPayoff` currently has `sorry` as its definition body. Replace with the proper finite sum over strategy profiles weighted by PMF probabilities.

```lean
noncomputable def expectedPayoff {n : Nat} (G : NormalFormGame n)
    (i : Fin n) (σ : MixedStrategyProfile G) : ℝ :=
  letI := fun j => G.strategyFintype j
  ∑ s : ((j : Fin n) → G.Strategy j),
    (∏ j : Fin n, ((σ j).val (s j)).toReal) * G.payoff i s
```

This computes: E[payoff_i] = Σ_s (∏_j σ_j(s_j)) · u_i(s), the standard expected payoff formula.

Required imports (add if not present):
```lean
import Mathlib.Data.Fintype.Pi
```

**Step: Build and verify**

Run: `cd proofs/lean && lake build Proofs.GameTheory.MixedNashExistence 2>&1 | grep -E "(error|sorry)"`
Expected: 1 sorry remaining (`mixed_nash_exists`), 0 errors.

### Task 9: Close budget_game_bridge

**Files:**
- Modify: `proofs/lean/Proofs/GameTheory/BudgetGameBridge.lean:72-79`

The bridge theorem needs `hSmall` added to its signature (since `moderate_is_nash_equilibrium` requires it).

```lean
theorem budget_game_bridge
    (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ∃ σ : Fin params.agentCount → AgentAction,
      (∀ i, actionViolates (σ i) = false) ∧
      IsNashEquilibrium (fulcrumCoordinationGame params) σ := by
  exact ⟨fun _ => AgentAction.moderate,
    fun i => by simp [actionViolates],
    moderate_is_nash_equilibrium params hBudget hSmall⟩
```

**Step: Build and verify**

Run: `cd proofs/lean && lake build Proofs.GameTheory.BudgetGameBridge 2>&1 | grep sorry`
Expected: 0 sorry.

**Step: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/MixedNashExistence.lean proofs/lean/Proofs/GameTheory/BudgetGameBridge.lean
git commit -m "feat(proofs): fix expectedPayoff definition, close budget_game_bridge"
```

---

## Phase 6: Full Build + Evidence Update

### Task 10: Full build verification and sorry audit

**Step 1: Full build**

Run: `cd proofs/lean && lake build 2>&1 | tail -30`
Expected: Build succeeds.

**Step 2: Sorry audit**

Run: `bash proofs/lean/scripts/check_no_sorry.sh 2>&1`
Expected: Only 1 sorry reported — `mixed_nash_exists` in MixedNashExistence.lean:98.

**Step 3: Update theorem inventory**

Update `claims/theorem_inventory.yaml`:
- Change all `proof_status: proven-with-sorry` to `proof_status: proven` for theorems that are now sorry-free
- Update `sorry_count` fields
- Keep `THM-NASH-MIXED-EXISTENCE` as `proven-with-sorry` with `sorry_count: 1`

**Step 4: Update claim ledger**

Update `claims/claim_ledger.yaml` and `claims/claim_scope.yaml`:
- C-018: Update notes to reflect 1 sorry (mixed Nash only)
- C-021: Change to `status: proven` (budget_game_bridge now sorry-free)

**Step 5: Commit**

```bash
git add claims/ proofs/lean/
git commit -m "evidence: reduce sorry count from 16 to 1 (mixed_nash_exists only)"
```

---

## Appendix A: The Remaining Sorry

`mixed_nash_exists` (MixedNashExistence.lean:98) cannot be closed because:

1. **Kakutani FPT is axiomatized** — both external repos (harfe v4.21, math-xmum v4.22) are incompatible with our Lean 4.29
2. **No Kakutani in Mathlib4** — confirmed by research (March 2026)
3. **The proof requires** showing upper hemicontinuity of the best-response correspondence, convexity of values, and applying Kakutani — this is deep functional analysis

**Resolution paths (future):**
- Wait for harfe/math-xmum to upgrade toolchains
- Wait for Mathlib4 to upstream Brouwer/Kakutani
- Port harfe's proof manually to v4.29 (estimated: significant effort)
- Use math-xmum's Brouwer+Scarf approach (bypasses Kakutani entirely)

## Appendix B: Key Tactic Patterns

**The sum_comp_update pattern** (from Gemini Deep Research):
```lean
rw [← Finset.add_sum_erase Finset.univ _ (Finset.mem_univ i)]
rw [Function.update_same]
congr 1
apply Finset.sum_congr rfl
intro j hj
rw [Finset.mem_erase] at hj
rw [Function.update_noteq hj.1]
```

**Nat → ℝ cast chain for payoff proofs:**
```lean
push_cast  -- pushes Nat.cast through arithmetic
nlinarith  -- nonlinear arithmetic with hypotheses
```

**Constant sum over Fin n:**
```lean
simp [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
```

## Appendix C: Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| Task 1 (helpers) | LOW — Gemini-verified pattern | Build test immediately |
| Tasks 2-5 (Nash) | MEDIUM — tactic engineering may need iteration | Each sorry is independent; close what works |
| Task 6 (PoA) | MEDIUM — Nash uniqueness lemma may need sorry | Accept 1 sorry in uniqueness if needed |
| Task 7 (IC) | MEDIUM — abs value arithmetic is fiddly | May need manual case split |
| Task 8 (expectedPayoff) | LOW — just a definition | Type-check should work |
| Task 9 (bridge) | LOW — witness construction | Depends on Task 4 |
