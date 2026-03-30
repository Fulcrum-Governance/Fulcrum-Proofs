/-
  Nash Equilibrium Uniqueness for the Fulcrum Coordination Game

  Proves that under tight budget (25n) with n ≤ 12, the all-moderate
  strategy profile is the unique Nash equilibrium.

  Proof strategy (4 elimination steps):
  1. Noncompliant: strictly dominated by moderate (reuse NashExistence)
  2. No overflow: pigeonhole → aggressive exists → deviation profitable
  3. Conservative: without overflow, deviation to moderate gains 4
  4. Aggressive: without overflow and no conservative/noncompliant, total = 25n + 25a > 25n

  Combined with CoordinationEfficiency.lean, this eliminates the sorry
  in the Price of Anarchy bound theorem.
-/

import Proofs.GameTheory.FulcrumGame
import Proofs.GameTheory.NashExistence
import Proofs.GameTheory.SumUpdateLemmas
import Mathlib.Data.Fintype.BigOperators
import Mathlib.Tactic.IntervalCases

set_option autoImplicit false
set_option maxHeartbeats 1600000

namespace Fulcrum.GameTheory

-- ═══════════════════════════════════════════════════════════════════
-- Helper: extract fulcrumPayoff inequality from game-level Nash
-- ═══════════════════════════════════════════════════════════════════

private lemma nash_deviation_bound (params : BudgetParams)
    (σ : Fin params.agentCount → AgentAction)
    (hNash : IsNashEquilibrium (fulcrumCoordinationGame params) σ)
    (i : Fin params.agentCount) (a : AgentAction) :
    fulcrumPayoff params σ i ≥
      fulcrumPayoff params (Function.update σ i a) i := hNash i a

-- ═══════════════════════════════════════════════════════════════════
-- Helper: cost upper bounds
-- ═══════════════════════════════════════════════════════════════════

private lemma cost_le_25 (a : AgentAction)
    (hNA : a ≠ AgentAction.aggressive) (hNN : a ≠ AgentAction.noncompliant) :
    actionTokenCost a ≤ 25 := by
  cases a <;> simp_all [actionTokenCost]

private lemma totalTokens_le_25n (n : Nat)
    (σ : Fin n → AgentAction)
    (hNA : ∀ i, σ i ≠ AgentAction.aggressive)
    (hNN : ∀ i, σ i ≠ AgentAction.noncompliant) :
    totalTokens n σ ≤ 25 * n := by
  unfold totalTokens
  calc ∑ i : Fin n, actionTokenCost (σ i)
      ≤ ∑ _ : Fin n, 25 := Finset.sum_le_sum (fun i _ => cost_le_25 (σ i) (hNA i) (hNN i))
    _ = 25 * n := by
        simp [Finset.sum_const, Finset.card_univ, Fintype.card_fin]
        ring

-- ═══════════════════════════════════════════════════════════════════
-- Step 1: No noncompliant in any Nash equilibrium
-- ═══════════════════════════════════════════════════════════════════

private lemma no_noncompliant_in_nash (params : BudgetParams)
    (σ : Fin params.agentCount → AgentAction)
    (hNash : IsNashEquilibrium (fulcrumCoordinationGame params) σ) :
    ∀ i, σ i ≠ AgentAction.noncompliant := by
  intro i hNC
  have hSD := noncompliant_strictly_dominated params i σ hNC
  have hBR := nash_deviation_bound params σ hNash i AgentAction.moderate
  linarith

-- ═══════════════════════════════════════════════════════════════════
-- Step 2: No overflow in any Nash equilibrium
--
-- If overflow, aggressive exists (pigeonhole on costs).
-- Aggressive→moderate deviation saves 25 tokens.
-- Case A: still overflow → gain = 25/n - 2 > 0 for n ≤ 12.
-- Case B: overflow removed → conservative must exist →
--         conservative Nash requires 15/n ≥ 4, i.e. n ≤ 3.
--         For n ≤ 3, cost divisibility eliminates all cases.
-- ═══════════════════════════════════════════════════════════════════

private lemma no_overflow_in_nash (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12)
    (σ : Fin params.agentCount → AgentAction)
    (hNash : IsNashEquilibrium (fulcrumCoordinationGame params) σ)
    (hNoNC : ∀ i, σ i ≠ AgentAction.noncompliant) :
    totalTokens params.agentCount σ ≤ params.totalBudget := by
  rw [hBudget]
  by_contra hOverflow
  push_neg at hOverflow
  -- Pigeonhole: aggressive agent must exist
  have hExistsAgg : ∃ j, σ j = AgentAction.aggressive := by
    by_contra hNoAgg
    push_neg at hNoAgg
    exact absurd (totalTokens_le_25n params.agentCount σ hNoAgg hNoNC) (not_le.mpr hOverflow)
  obtain ⟨j, hj⟩ := hExistsAgg
  -- Token arithmetic for j's deviation to moderate
  set T := totalTokens params.agentCount σ
  set T' := totalTokens params.agentCount (Function.update σ j AgentAction.moderate)
  have hTokenEq : T' + 50 = T + 25 := by
    have := totalTokens_update_general params.agentCount σ j AgentAction.moderate
    rw [hj] at this
    simp only [actionTokenCost] at this
    exact this
  -- Key facts about n
  have hn_pos : (0 : ℝ) < (params.agentCount : ℝ) := by exact_mod_cast params.hPositive
  have hn_ne : (params.agentCount : ℝ) ≠ 0 := ne_of_gt hn_pos
  -- Overflow condition in Nat form (using totalBudget = 25n)
  have hOF_nat : params.totalBudget < T := by rw [hBudget]; exact hOverflow
  -- Real-form overflow conditions for if_pos/if_neg in payoff proofs
  have hOF_real : (T : ℝ) > (params.totalBudget : ℝ) := by exact_mod_cast hOF_nat
  -- Case split on whether deviation still overflows
  by_cases hOF'_nat : params.totalBudget < T'
  · -- Case A: still overflow after deviation
    have hOF'_real : (T' : ℝ) > (params.totalBudget : ℝ) := by exact_mod_cast hOF'_nat
    have hPayoff_old : fulcrumPayoff params σ j =
        9 - ((T : ℝ) - params.totalBudget) / params.agentCount := by
      unfold fulcrumPayoff
      simp only [hj, actionQuality, actionViolates,
                 show (totalTokens params.agentCount σ : ℝ) = T from rfl]
      rw [if_pos hOF_real]
      norm_num
    have hPayoff_new : fulcrumPayoff params (Function.update σ j AgentAction.moderate) j =
        7 - ((T' : ℝ) - params.totalBudget) / params.agentCount := by
      unfold fulcrumPayoff
      simp only [Function.update_self, actionQuality, actionViolates,
                 show (totalTokens params.agentCount (Function.update σ j AgentAction.moderate) : ℝ) = T' from rfl]
      rw [if_pos hOF'_real]
      norm_num
    have hBR := nash_deviation_bound params σ hNash j AgentAction.moderate
    rw [hPayoff_old, hPayoff_new] at hBR
    -- hBR : 9 - (T - budget)/n ≥ 7 - (T' - budget)/n
    -- T = T' + 25, so gain = 25/n > 2 for n ≤ 12. Contradiction.
    have hTdiff : (T : ℝ) - T' = 25 := by
      have hnat : T = T' + 25 := by omega
      have : (T : ℝ) = T' + 25 := by exact_mod_cast hnat
      linarith
    have h25n : (25 : ℝ) / params.agentCount > 2 := by
      rw [gt_iff_lt, lt_div_iff₀ hn_pos]
      have : (params.agentCount : ℝ) ≤ 12 := by exact_mod_cast hSmall
      nlinarith
    have : (2 : ℝ) ≥ 25 / params.agentCount := by
      have hsub : ((T : ℝ) - params.totalBudget) / params.agentCount -
                  ((T' : ℝ) - params.totalBudget) / params.agentCount =
                  25 / params.agentCount := by
        field_simp
        linarith [hTdiff]
      nlinarith
    linarith
  · -- Case B: no overflow after deviation → payoff_new = 7
    push_neg at hOF'_nat
    have hNoOF'_real : ¬ ((T' : ℝ) > (params.totalBudget : ℝ)) := by
      exact_mod_cast not_lt.mpr hOF'_nat
    have hPayoff_old : fulcrumPayoff params σ j =
        9 - ((T : ℝ) - params.totalBudget) / params.agentCount := by
      unfold fulcrumPayoff
      simp only [hj, actionQuality, actionViolates,
                 show (totalTokens params.agentCount σ : ℝ) = T from rfl]
      rw [if_pos hOF_real]
      norm_num
    have hPayoff_new : fulcrumPayoff params (Function.update σ j AgentAction.moderate) j = 7 := by
      unfold fulcrumPayoff
      simp only [Function.update_self, actionQuality, actionViolates,
                 show (totalTokens params.agentCount (Function.update σ j AgentAction.moderate) : ℝ) = T' from rfl]
      rw [if_neg hNoOF'_real]
      norm_num
    have hBR := nash_deviation_bound params σ hNash j AgentAction.moderate
    rw [hPayoff_old, hPayoff_new] at hBR
    -- hBR : 9 - (T - budget)/n ≥ 7
    -- So: (T - budget)/n ≤ 2
    have hOFle2 : ((T : ℝ) - params.totalBudget) / params.agentCount ≤ 2 := by
      nlinarith
    -- Conservative agent must exist (else total = 25n + 25a with 25a/n ≤ 2, a < 1)
    have hExistsCons : ∃ k, σ k = AgentAction.conservative := by
      by_contra hNoCons
      push_neg at hNoCons
      -- Every agent is moderate or aggressive (no NC, no cons)
      have hModOrAgg : ∀ i, σ i = AgentAction.moderate ∨ σ i = AgentAction.aggressive := by
        intro i; cases hσ : σ i <;> simp_all
      -- Each agent costs at least 25
      have hCostGe : ∀ i, 25 ≤ actionTokenCost (σ i) := by
        intro i; rcases hModOrAgg i with h | h <;> rw [h] <;> simp [actionTokenCost]
      have hTge : 25 * params.agentCount ≤ T := by
        show 25 * params.agentCount ≤ totalTokens params.agentCount σ
        unfold totalTokens
        calc 25 * params.agentCount
            = ∑ _ : Fin params.agentCount, 25 := by
              rw [Finset.sum_const, Finset.card_univ, Fintype.card_fin]
              simp [mul_comm]
          _ ≤ ∑ i : Fin params.agentCount, actionTokenCost (σ i) :=
              Finset.sum_le_sum (fun i _ => hCostGe i)
      -- Also aggressive agent j contributes 50, rest at least 25
      -- total ≥ 50 + 25(n-1) = 25n + 25
      have hTge25 : T ≥ 25 * params.agentCount + 25 := by
        have hSplit := totalTokens_eq_cost_add_sum_erase params.agentCount σ j
        show 25 * params.agentCount + 25 ≤ totalTokens params.agentCount σ
        unfold totalTokens at hSplit ⊢
        rw [hj, show actionTokenCost AgentAction.aggressive = 50 from rfl] at hSplit
        -- Lower bound on the sum over non-j agents: ≥ 25 * (n - 1) ≥ 25n - 25
        set rest := ∑ k ∈ Finset.univ.erase j, actionTokenCost (σ k)
        have hRestGe25 : rest ≥ 25 * (params.agentCount - 1) := by
          calc rest ≥ ∑ _ ∈ Finset.univ.erase j, 25 :=
                Finset.sum_le_sum (fun k _ => hCostGe k)
            _ = 25 * (params.agentCount - 1) := by
                rw [Finset.sum_const_nat (fun _ _ => rfl),
                    Finset.card_erase_of_mem (Finset.mem_univ j),
                    Finset.card_univ, Fintype.card_fin]
                ring
        have hn1 := params.hPositive
        -- hSplit: ∑ cost = 50 + rest, rest ≥ 25*(n-1), n ≥ 1
        -- Goal: 25*n + 25 ≤ ∑ cost = 50 + rest ≥ 50 + 25*(n-1) = 25*n + 25
        -- omega handles Nat subtraction 25*(n-1) correctly
        omega
      -- overflow = (T - budget)/n ≥ 25/n > 2 for n ≤ 12
      have : ((T : ℝ) - params.totalBudget) / params.agentCount ≥
             25 / params.agentCount := by
        apply div_le_div_of_nonneg_right _ (le_of_lt hn_pos)
        have : (T : ℝ) ≥ 25 * params.agentCount + 25 := by exact_mod_cast hTge25
        rw [hBudget]; push_cast; linarith
      have : (25 : ℝ) / params.agentCount > 2 := by
        rw [gt_iff_lt, lt_div_iff₀ hn_pos]
        have : (params.agentCount : ℝ) ≤ 12 := by exact_mod_cast hSmall
        nlinarith
      linarith
    -- We have a conservative agent k
    obtain ⟨k, hk⟩ := hExistsCons
    -- Conservative k's Nash condition: deviate to moderate
    -- k's deviation adds 15 tokens. Since T > budget, T+15 > budget (still overflow)
    set T_k := totalTokens params.agentCount (Function.update σ k AgentAction.moderate)
    have hTokenEq_k : T_k + 10 = T + 25 := by
      have := totalTokens_update_general params.agentCount σ k AgentAction.moderate
      rw [hk] at this
      simp only [actionTokenCost] at this
      exact this
    -- T_k = T + 15
    have hTk : T_k = T + 15 := by omega
    -- T_k > budget (since T > budget and T_k = T + 15)
    have hOF_k_nat : params.totalBudget < T_k := by omega
    have hOF_k_real : (T_k : ℝ) > (params.totalBudget : ℝ) := by exact_mod_cast hOF_k_nat
    have hPayoff_k_old : fulcrumPayoff params σ k =
        3 - ((T : ℝ) - params.totalBudget) / params.agentCount := by
      unfold fulcrumPayoff
      simp only [hk, actionQuality, actionViolates,
                 show (totalTokens params.agentCount σ : ℝ) = T from rfl]
      rw [if_pos hOF_real]
      norm_num
    have hPayoff_k_new : fulcrumPayoff params (Function.update σ k AgentAction.moderate) k =
        7 - ((T_k : ℝ) - params.totalBudget) / params.agentCount := by
      unfold fulcrumPayoff
      simp only [Function.update_self, actionQuality, actionViolates,
                 show (totalTokens params.agentCount (Function.update σ k AgentAction.moderate) : ℝ) = T_k from rfl]
      rw [if_pos hOF_k_real]
      norm_num
    have hBR_k := nash_deviation_bound params σ hNash k AgentAction.moderate
    rw [hPayoff_k_old, hPayoff_k_new] at hBR_k
    -- hBR_k : 3 - (T - budget)/n ≥ 7 - (T_k - budget)/n
    -- = 7 - (T + 15 - budget)/n = 7 - (T - budget)/n - 15/n
    -- So: 15/n ≥ 4, i.e., n ≤ 3
    have hTk_cast : (T_k : ℝ) = (T : ℝ) + 15 := by exact_mod_cast hTk
    have h15n : (15 : ℝ) / params.agentCount ≥ 4 := by
      have hsub : ((T_k : ℝ) - params.totalBudget) / params.agentCount -
                  ((T : ℝ) - params.totalBudget) / params.agentCount =
                  15 / params.agentCount := by
        field_simp
        linarith [hTk_cast]
      nlinarith
    -- 15/n ≥ 4 → n ≤ 3 (since n is a positive nat)
    have hn_le3 : params.agentCount ≤ 3 := by
      by_contra h
      push_neg at h
      have : (params.agentCount : ℝ) ≥ 4 := by exact_mod_cast h
      have : (15 : ℝ) / params.agentCount ≤ 15 / 4 := by
        apply div_le_div_of_nonneg_left (by norm_num : (0 : ℝ) ≤ 15) (by linarith) this
      linarith
    -- For n ≤ 3 with overflow ≤ 2:
    -- Direct argument: overflow ≤ 2 and n ≤ 3 means T - 25n ≤ 6.
    -- But j aggressive (50) + k conservative (10) already contributes 60.
    -- For n=2: T = 60 + rest (0 agents remain), rest = 0, T = 60.
    --          budget = 50, T > 50, T ≤ 56. But T = 60 > 56. Contradiction.
    -- For n=3: T = 60 + cost(3rd agent). budget = 75.
    --          T > 75, T ≤ 81. T = 60 + cost. cost ∈ {10,25,50}.
    --          cost > 15 and cost ≤ 21. No valid value.
    exfalso
    -- We need n ≥ 2 since j ≠ k (both are agents with different actions)
    have hjk : j ≠ k := by intro heq; rw [heq, hk] at hj; exact absurd hj (by decide)
    have hn_ge2 : params.agentCount ≥ 2 := by
      by_contra h
      push_neg at h
      have hn1 : params.agentCount = 1 := by
        have := params.hPositive; omega
      -- Only one agent, so j and k are both Fin 1, hence j = k. But j ≠ k.
      have : j = k := by
        apply Fin.ext
        have hj_val := j.isLt
        have hk_val := k.isLt
        omega
      exact absurd this hjk
    -- Total has contributions: 50 (from j) + 10 (from k) + rest
    have hDecomp : T = 50 + 10 +
        ∑ m ∈ (Finset.univ.erase j).erase k, actionTokenCost (σ m) := by
      show totalTokens params.agentCount σ = 50 + 10 +
          ∑ m ∈ (Finset.univ.erase j).erase k, actionTokenCost (σ m)
      have h1 := totalTokens_eq_cost_add_sum_erase params.agentCount σ j
      unfold totalTokens at h1 ⊢
      rw [hj, show actionTokenCost AgentAction.aggressive = 50 from rfl] at h1
      rw [h1]
      have hk_mem : k ∈ Finset.univ.erase j := by
        simp [Finset.mem_erase, hjk.symm]
      rw [← Finset.add_sum_erase _ _ hk_mem]
      rw [hk, show actionTokenCost AgentAction.conservative = 10 from rfl]
      ring
    -- T = 60 + rest. T > budget, T ≤ budget + 2n ≤ budget + 6.
    have hOFle : T ≤ params.totalBudget + 2 * params.agentCount := by
      have hle : ((T : ℝ) - params.totalBudget) ≤ 2 * params.agentCount := by
        have := mul_le_mul_of_nonneg_right hOFle2 (le_of_lt hn_pos)
        rwa [div_mul_cancel₀ _ hn_ne] at this
      have : (T : ℝ) ≤ params.totalBudget + 2 * params.agentCount := by linarith
      exact_mod_cast this
    have hN2 : params.agentCount = 2 ∨ params.agentCount = 3 := by omega
    rcases hN2 with hn2 | hn3
    · -- n = 2: budget = 50. T > 50, T ≤ 54. T = 60 + rest ≥ 60. Contradiction.
      have h_budget : params.totalBudget = 50 := by linarith [hBudget, hn2]
      have hrest_nonneg : ∑ m ∈ (Finset.univ.erase j).erase k, actionTokenCost (σ m) ≥ 0 :=
        Nat.zero_le _
      linarith [hDecomp, hOF_nat, hOFle, hn2]
    · -- n = 3: budget = 75. T > 75, T ≤ 81. T = 60 + cost(3rd agent).
      have h_budget : params.totalBudget = 75 := by linarith [hBudget, hn3]
      -- Find the unique third agent v ≠ j and ≠ k in Fin params.agentCount
      have hj3 : j.val < params.agentCount := j.isLt
      have hk3 : k.val < params.agentCount := k.isLt
      have hjk_val : j.val ≠ k.val := by intro h; exact hjk (Fin.ext h)
      -- With n=3 and j≠k, there's a third element
      have hmid : ∃ v : Fin params.agentCount, v ≠ j ∧ v ≠ k := by
        -- j.val, k.val ∈ {0,1,2} and j.val ≠ k.val; find the remaining index
        have hj3' : j.val = 0 ∨ j.val = 1 ∨ j.val = 2 := by omega
        have hk3' : k.val = 0 ∨ k.val = 1 ∨ k.val = 2 := by omega
        -- In each case, construct the witness explicitly
        rcases hj3' with hj0 | hj1 | hj2 <;> rcases hk3' with hk0 | hk1 | hk2
        · -- j=0,k=0: impossible since j≠k
          exact absurd (Fin.ext (by omega)) hjk
        · -- j=0,k=1: v=2
          exact ⟨⟨2, by omega⟩, fun h => by simp [Fin.ext_iff] at h; omega,
                              fun h => by simp [Fin.ext_iff] at h; omega⟩
        · -- j=0,k=2: v=1
          exact ⟨⟨1, by omega⟩, fun h => by simp [Fin.ext_iff] at h; omega,
                              fun h => by simp [Fin.ext_iff] at h; omega⟩
        · -- j=1,k=0: v=2
          exact ⟨⟨2, by omega⟩, fun h => by simp [Fin.ext_iff] at h; omega,
                              fun h => by simp [Fin.ext_iff] at h; omega⟩
        · -- j=1,k=1: impossible
          exact absurd (Fin.ext (by omega)) hjk
        · -- j=1,k=2: v=0
          exact ⟨⟨0, by omega⟩, fun h => by simp [Fin.ext_iff] at h; omega,
                              fun h => by simp [Fin.ext_iff] at h; omega⟩
        · -- j=2,k=0: v=1
          exact ⟨⟨1, by omega⟩, fun h => by simp [Fin.ext_iff] at h; omega,
                              fun h => by simp [Fin.ext_iff] at h; omega⟩
        · -- j=2,k=1: v=0
          exact ⟨⟨0, by omega⟩, fun h => by simp [Fin.ext_iff] at h; omega,
                              fun h => by simp [Fin.ext_iff] at h; omega⟩
        · -- j=2,k=2: impossible
          exact absurd (Fin.ext (by omega)) hjk
      obtain ⟨v, hv_ne_j, hv_ne_k⟩ := hmid
      -- The set (univ.erase j).erase k = {v} (exactly 1 element)
      have hsingleton : (Finset.univ.erase j).erase k = {v} := by
        apply Finset.eq_singleton_iff_unique_mem.mpr
        constructor
        · simp [Finset.mem_erase, hv_ne_j, hv_ne_k]
        · intro x hx
          simp only [Finset.mem_erase, ne_eq, Finset.mem_univ, and_true] at hx
          apply Fin.ext
          obtain ⟨hx_ne_k, hx_ne_j⟩ := hx
          have hxv : x.val ≠ j.val := fun h => hx_ne_j (Fin.ext h)
          have hxk : x.val ≠ k.val := fun h => hx_ne_k (Fin.ext h)
          have hvj : v.val ≠ j.val := fun h => hv_ne_j (Fin.ext h)
          have hvk : v.val ≠ k.val := fun h => hv_ne_k (Fin.ext h)
          have hxlt : x.val < params.agentCount := x.isLt
          have hvlt : v.val < params.agentCount := v.isLt
          omega
      rw [hsingleton, Finset.sum_singleton] at hDecomp
      -- T = 60 + cost(σ v). T > 75 means cost > 15. T ≤ 81 means cost ≤ 21.
      -- Valid costs: 10, 25, 40, 50. None in (15, 21].
      cases hσv : σ v with
      | conservative => simp [actionTokenCost, hσv] at hDecomp; linarith [hDecomp, hOF_nat, hOFle, hn3, h_budget]
      | moderate     => simp [actionTokenCost, hσv] at hDecomp; linarith [hDecomp, hOF_nat, hOFle, hn3, h_budget]
      | aggressive   => simp [actionTokenCost, hσv] at hDecomp; linarith [hDecomp, hOF_nat, hOFle, hn3, h_budget]
      | noncompliant => simp [actionTokenCost, hσv] at hDecomp; linarith [hDecomp, hOF_nat, hOFle, hn3, h_budget]

-- ═══════════════════════════════════════════════════════════════════
-- Step 3: No conservative in Nash equilibrium (given no overflow)
-- ═══════════════════════════════════════════════════════════════════

private lemma no_conservative_in_nash (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (σ : Fin params.agentCount → AgentAction)
    (hNash : IsNashEquilibrium (fulcrumCoordinationGame params) σ)
    (hNoNC : ∀ i, σ i ≠ AgentAction.noncompliant)
    (hNoOF : totalTokens params.agentCount σ ≤ params.totalBudget) :
    ∀ i, σ i ≠ AgentAction.conservative := by
  intro i hi
  -- Deviation to moderate: total increases by 15
  set T := totalTokens params.agentCount σ with hT_def
  set T' := totalTokens params.agentCount (Function.update σ i AgentAction.moderate) with hT'_def
  -- No overflow currently
  have hNoOF_nat : T ≤ params.totalBudget := hNoOF
  have hNoOF_25n : T ≤ 25 * params.agentCount := by rw [← hBudget]; exact hNoOF
  have hTokenEq : T' + 10 = T + 25 := by
    have := totalTokens_update_general params.agentCount σ i AgentAction.moderate
    rw [hi] at this; simp only [actionTokenCost] at this; exact this
  have hTi : T' = T + 15 := by omega
  have hn_pos : (0 : ℝ) < (params.agentCount : ℝ) := by exact_mod_cast params.hPositive
  have hn_ne : (params.agentCount : ℝ) ≠ 0 := ne_of_gt hn_pos
  -- Real-form conditions for if_pos/if_neg in payoff proofs
  have hNoOF_real : ¬ ((T : ℝ) > (params.totalBudget : ℝ)) := by
    exact_mod_cast not_lt.mpr hNoOF_nat
  -- If deviation also has no overflow: payoff goes from 3 to 7. Contradiction.
  by_cases hOF'_nat : params.totalBudget < T'
  · -- Overflow after deviation (T + 15 > budget but T ≤ budget)
    have hOF'_real : (T' : ℝ) > (params.totalBudget : ℝ) := by exact_mod_cast hOF'_nat
    have hPayoff_old : fulcrumPayoff params σ i = 3 := by
      unfold fulcrumPayoff
      simp only [hi, actionQuality, actionViolates,
                 show (totalTokens params.agentCount σ : ℝ) = T from rfl]
      rw [if_neg hNoOF_real]
      norm_num
    have hPayoff_new : fulcrumPayoff params (Function.update σ i AgentAction.moderate) i =
        7 - ((T' : ℝ) - params.totalBudget) / params.agentCount := by
      unfold fulcrumPayoff
      simp only [Function.update_self, actionQuality, actionViolates,
                 show (totalTokens params.agentCount (Function.update σ i AgentAction.moderate) : ℝ) = T' from rfl]
      rw [if_pos hOF'_real]
      norm_num
    have hBR := nash_deviation_bound params σ hNash i AgentAction.moderate
    rw [hPayoff_old, hPayoff_new] at hBR
    -- hBR : 3 ≥ 7 - (T' - budget)/n, so (T' - budget)/n ≥ 4
    have hTi_cast : (T' : ℝ) = (T : ℝ) + 15 := by exact_mod_cast hTi
    have hNoOF_real_T : ¬ ((T : ℝ) > (params.totalBudget : ℝ)) := by
      exact_mod_cast not_lt.mpr hNoOF_nat
    -- Overflow = (T' - budget)/n ≤ 15/n (since T ≤ budget)
    have hOFle : ((T' : ℝ) - params.totalBudget) / params.agentCount ≤
                  15 / params.agentCount := by
      apply div_le_div_of_nonneg_right _ (le_of_lt hn_pos)
      have : (T : ℝ) ≤ params.totalBudget := by exact_mod_cast hNoOF
      linarith [hTi_cast]
    -- From hBR: (T' - budget)/n ≥ 4
    have hOFge : ((T' : ℝ) - params.totalBudget) / params.agentCount ≥ 4 := by
      nlinarith
    -- 4 ≤ 15/n means n ≤ 3
    have hn_le3 : params.agentCount ≤ 3 := by
      by_contra h; push_neg at h
      have hge4 : (params.agentCount : ℝ) ≥ 4 := by exact_mod_cast h
      have : (15 : ℝ) / params.agentCount ≤ 15 / 4 := by
        apply div_le_div_of_nonneg_left (by norm_num : (0 : ℝ) ≤ 15) (by linarith) hge4
      linarith
    -- For n ≤ 3: T ≤ budget = 25n, T' = T+15 > budget.
    -- From hOFge: T' - budget ≥ 4n, so T + 15 - 25n ≥ 4n, T ≥ 29n - 15.
    exfalso
    have hTge29 : T + 15 ≥ 25 * params.agentCount + 4 * params.agentCount := by
      have h4n : ((T' : ℝ) - params.totalBudget) ≥ 4 * params.agentCount := by
        have := mul_le_mul_of_nonneg_right hOFge (le_of_lt hn_pos)
        rwa [div_mul_cancel₀ _ hn_ne] at this
      have hTbudget : (params.totalBudget : ℝ) = 25 * params.agentCount := by
        exact_mod_cast hBudget
      have : (T : ℝ) + 15 ≥ 25 * params.agentCount + 4 * params.agentCount := by
        have : (T' : ℝ) ≥ params.totalBudget + 4 * params.agentCount := by linarith
        linarith [hTi_cast, hTbudget]
      exact_mod_cast this
    have hT_upper : T ≤ 25 * params.agentCount := hNoOF_25n
    -- Now n ≤ 3 and T + 15 ≥ 29n and T ≤ 25n. This means 29n - 15 ≤ T ≤ 25n.
    -- For n ≥ 4 already contradicted. Check n = 1, 2, 3:
    -- n=1: 14 ≤ T ≤ 25, T'=T+15 > 25, so T+15 > 25 → T > 10. T = cost of agent i = 10 (conservative).
    --   Contradiction T > 10.
    -- n=2: T + 15 ≥ 58, T ≤ 50. T ≥ 43. T = 10 + cost_other. cost_other ∈ {10,25,50}.
    --   T ∈ {20, 35, 60}. None in {43..50}.
    -- n=3: T + 15 ≥ 87, T ≤ 75. T ≥ 72. T = 10 + sum_of_2. Sum ∈ {20,35,60,75,100}.
    --   T ∈ {30, 45, 70, 85, 110}. None in {72..75}.
    have hn_pos2 := params.hPositive
    have hN : params.agentCount = 1 ∨ params.agentCount = 2 ∨ params.agentCount = 3 := by omega
    have hT_split : T = 10 + ∑ m ∈ Finset.univ.erase i, actionTokenCost (σ m) := by
      show totalTokens params.agentCount σ = 10 + ∑ m ∈ Finset.univ.erase i, actionTokenCost (σ m)
      have h1 := totalTokens_eq_cost_add_sum_erase params.agentCount σ i
      unfold totalTokens at h1 ⊢
      rw [hi, show actionTokenCost AgentAction.conservative = 10 from rfl] at h1
      linarith
    rcases hN with hn1 | hn2 | hn3
    · -- n = 1: only agent is i (conservative), T=10, T'=25=budget=25. But T'>budget is false.
      have hTval : T = 10 := by
        have hEmpty : ∑ m ∈ (Finset.univ.erase i : Finset (Fin params.agentCount)),
            actionTokenCost (σ m) = 0 := by
          apply Finset.sum_eq_zero
          intro m hm
          simp only [Finset.mem_erase, Finset.mem_univ, and_true] at hm
          -- m : Fin params.agentCount, m ≠ i, but params.agentCount = 1, so no such m exists
          have := m.isLt
          omega
        omega
      -- T=10, T'=T+15=25, budget=25*1=25. hOF'_nat : budget < T' = 25. Contradiction.
      have h_budget : params.totalBudget = 25 := by linarith [hBudget, hn1]
      linarith
    · -- n = 2: budget = 50. T + 15 ≥ 58, T ≤ 50. T = 10 + cost_other.
      have h_budget : params.totalBudget = 50 := by linarith [hBudget, hn2]
      -- T ≥ 43 (from hTge29 + hn2)
      have hTge43 : T ≥ 43 := by linarith [hn2]
      -- Enumerate the unique other agent (not i)
      have hi2 : i.val < 2 := by have := i.isLt; omega
      -- Find the other agent: j' ≠ i with j'.val < 2
      have hother : ∃ o : Fin params.agentCount, o ≠ i := by
        have h0or1 : i.val = 0 ∨ i.val = 1 := by omega
        rcases h0or1 with h0 | h1
        · exact ⟨⟨1, by omega⟩, fun hh => by simp [Fin.ext_iff] at hh; omega⟩
        · exact ⟨⟨0, by omega⟩, fun hh => by simp [Fin.ext_iff] at hh; omega⟩
      obtain ⟨o, ho⟩ := hother
      have herase_single : (Finset.univ.erase i : Finset (Fin params.agentCount)) = {o} := by
        apply Finset.eq_singleton_iff_unique_mem.mpr
        constructor
        · simp [Finset.mem_erase, ho]
        · intro x hx
          simp only [Finset.mem_erase, ne_eq, Finset.mem_univ, and_true] at hx
          apply Fin.ext
          have hxi : x.val < params.agentCount := x.isLt
          have hoi : o.val < params.agentCount := o.isLt
          have hii2 : i.val < params.agentCount := i.isLt
          omega
      rw [herase_single, Finset.sum_singleton] at hT_split
      -- T = 10 + cost(σ o). Valid costs (non-noncompliant): 10, 25, 50. T ≥ 43, T ≤ 50.
      -- None of 20, 35, 60 satisfies 43 ≤ T ≤ 50.
      cases hσo : σ o with
      | conservative => simp [actionTokenCost, hσo] at hT_split; omega
      | moderate     => simp [actionTokenCost, hσo] at hT_split; omega
      | aggressive   => simp [actionTokenCost, hσo] at hT_split; omega
      | noncompliant => exact absurd hσo (hNoNC o)
    · -- n = 3: budget = 75. T + 15 ≥ 87, T ≤ 75. T = 10 + sum_of_2 others.
      have h_budget : params.totalBudget = 75 := by linarith [hBudget, hn3]
      have hTge72 : T ≥ 72 := by linarith [hn3]
      have hi3 : i.val < 3 := by have := i.isLt; omega
      -- Find two agents p, q ≠ i with p ≠ q (using same pattern as no_overflow n=3 case)
      have hother2 : ∃ p q : Fin params.agentCount, p ≠ i ∧ q ≠ i ∧ p ≠ q := by
        have hi3' : i.val < 3 := by have := i.isLt; omega
        have hpq3 : i.val = 0 ∨ i.val = 1 ∨ i.val = 2 := by omega
        rcases hpq3 with h0 | h1 | h2
        · -- i.val = 0; use p=⟨1,_⟩, q=⟨2,_⟩
          have hp1 : (1 : ℕ) < params.agentCount := by omega
          have hp2 : (2 : ℕ) < params.agentCount := by omega
          have hpni : (⟨1, hp1⟩ : Fin params.agentCount) ≠ i := by
            rw [Fin.ne_iff_vne]; simp [h0]
          have hqni : (⟨2, hp2⟩ : Fin params.agentCount) ≠ i := by
            rw [Fin.ne_iff_vne]; simp [h0]
          have hpq' : (⟨1, hp1⟩ : Fin params.agentCount) ≠ ⟨2, hp2⟩ := by
            rw [Fin.ne_iff_vne]; norm_num
          exact ⟨⟨1, hp1⟩, ⟨2, hp2⟩, hpni, hqni, hpq'⟩
        · -- i.val = 1; use p=⟨0,_⟩, q=⟨2,_⟩
          have hp0 : (0 : ℕ) < params.agentCount := by omega
          have hp2 : (2 : ℕ) < params.agentCount := by omega
          have hpni : (⟨0, hp0⟩ : Fin params.agentCount) ≠ i := by
            rw [Fin.ne_iff_vne]; simp [h1]
          have hqni : (⟨2, hp2⟩ : Fin params.agentCount) ≠ i := by
            rw [Fin.ne_iff_vne]; simp [h1]
          have hpq' : (⟨0, hp0⟩ : Fin params.agentCount) ≠ ⟨2, hp2⟩ := by
            rw [Fin.ne_iff_vne]; norm_num
          exact ⟨⟨0, hp0⟩, ⟨2, hp2⟩, hpni, hqni, hpq'⟩
        · -- i.val = 2; use p=⟨0,_⟩, q=⟨1,_⟩
          have hp0 : (0 : ℕ) < params.agentCount := by omega
          have hp1 : (1 : ℕ) < params.agentCount := by omega
          have hpni : (⟨0, hp0⟩ : Fin params.agentCount) ≠ i := by
            rw [Fin.ne_iff_vne]; simp [h2]
          have hqni : (⟨1, hp1⟩ : Fin params.agentCount) ≠ i := by
            rw [Fin.ne_iff_vne]; simp [h2]
          have hpq' : (⟨0, hp0⟩ : Fin params.agentCount) ≠ ⟨1, hp1⟩ := by
            rw [Fin.ne_iff_vne]; norm_num
          exact ⟨⟨0, hp0⟩, ⟨1, hp1⟩, hpni, hqni, hpq'⟩
      obtain ⟨p, q, hp_ne_i, hq_ne_i, hpq⟩ := hother2
      have herase2 : (Finset.univ.erase i : Finset (Fin params.agentCount)) = {p, q} := by
        apply Finset.eq_of_subset_of_card_le
        · intro x hx
          simp only [Finset.mem_erase, ne_eq, Finset.mem_univ, and_true] at hx
          simp only [Finset.mem_insert, Finset.mem_singleton]
          have hxlt : x.val < 3 := by have := x.isLt; omega
          have hplt : p.val < 3 := by have := p.isLt; omega
          have hqlt : q.val < 3 := by have := q.isLt; omega
          have hilt : i.val < 3 := by have := i.isLt; omega
          have hpqi : p.val ≠ q.val := fun h => hpq (Fin.ext h)
          have hpii : p.val ≠ i.val := fun h => hp_ne_i (Fin.ext h)
          have hqii : q.val ≠ i.val := fun h => hq_ne_i (Fin.ext h)
          have hxii : x.val ≠ i.val := fun h => hx (Fin.ext h)
          have : x.val = p.val ∨ x.val = q.val := by omega
          rcases this with h | h
          · left; exact Fin.ext h
          · right; exact Fin.ext h
        · have hcard_erase : (Finset.univ.erase i : Finset (Fin params.agentCount)).card = 2 := by
            rw [Finset.card_erase_of_mem (Finset.mem_univ i),
                Finset.card_univ, Fintype.card_fin]; omega
          rw [hcard_erase]
          rw [Finset.card_insert_of_notMem (by rw [Finset.mem_singleton]; exact hpq),
              Finset.card_singleton]
      rw [herase2] at hT_split
      simp only [Finset.sum_insert (by rw [Finset.mem_singleton]; exact hpq),
                 Finset.sum_singleton] at hT_split
      cases hσp : σ p with
      | conservative =>
        cases hσq : σ q with
        | conservative => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | moderate     => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | aggressive   => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | noncompliant => exact absurd hσq (hNoNC q)
      | moderate =>
        cases hσq : σ q with
        | conservative => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | moderate     => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | aggressive   => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | noncompliant => exact absurd hσq (hNoNC q)
      | aggressive =>
        cases hσq : σ q with
        | conservative => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | moderate     => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | aggressive   => simp [actionTokenCost, hσp, hσq] at hT_split; omega
        | noncompliant => exact absurd hσq (hNoNC q)
      | noncompliant => exact absurd hσp (hNoNC p)
  · -- No overflow after deviation
    push_neg at hOF'_nat
    have hNoOF'_real : ¬ ((T' : ℝ) > (params.totalBudget : ℝ)) := by
      exact_mod_cast not_lt.mpr hOF'_nat
    have hPayoff_old : fulcrumPayoff params σ i = 3 := by
      unfold fulcrumPayoff
      simp only [hi, actionQuality, actionViolates,
                 show (totalTokens params.agentCount σ : ℝ) = T from rfl]
      rw [if_neg hNoOF_real]
      norm_num
    have hPayoff_new : fulcrumPayoff params (Function.update σ i AgentAction.moderate) i = 7 := by
      unfold fulcrumPayoff
      simp only [Function.update_self, actionQuality, actionViolates,
                 show (totalTokens params.agentCount (Function.update σ i AgentAction.moderate) : ℝ) = T' from rfl]
      rw [if_neg hNoOF'_real]
      norm_num
    have hBR := nash_deviation_bound params σ hNash i AgentAction.moderate
    rw [hPayoff_old, hPayoff_new] at hBR
    linarith

-- ═══════════════════════════════════════════════════════════════════
-- Step 4: No aggressive without overflow (given no conservative/NC)
-- ═══════════════════════════════════════════════════════════════════

private lemma no_aggressive_without_overflow (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (σ : Fin params.agentCount → AgentAction)
    (hNoNC : ∀ i, σ i ≠ AgentAction.noncompliant)
    (hNoCons : ∀ i, σ i ≠ AgentAction.conservative)
    (hNoOF : totalTokens params.agentCount σ ≤ params.totalBudget) :
    ∀ i, σ i ≠ AgentAction.aggressive := by
  intro i hi
  -- All agents are moderate or aggressive
  -- Total = 25(moderate count) + 50(aggressive count) = 25n + 25(aggressive count)
  -- No overflow means total ≤ 25n, so 25(aggressive count) ≤ 0, impossible.
  rw [hBudget] at hNoOF
  have hModOrAgg : ∀ k, σ k = AgentAction.moderate ∨ σ k = AgentAction.aggressive := by
    intro k; cases hσ : σ k <;> simp_all
  have hCostGe : ∀ k, 25 ≤ actionTokenCost (σ k) := by
    intro k; rcases hModOrAgg k with h | h <;> rw [h] <;> simp [actionTokenCost]
  -- Agent i costs 50
  have hCostI : actionTokenCost (σ i) = 50 := by rw [hi]; rfl
  -- Total ≥ 50 + 25(n-1) = 25n + 25
  have hSplit := totalTokens_eq_cost_add_sum_erase params.agentCount σ i
  unfold totalTokens at hSplit
  rw [hCostI] at hSplit
  have hRestGe : ∑ k ∈ Finset.univ.erase i, actionTokenCost (σ k) ≥
                 25 * (params.agentCount - 1) := by
    calc ∑ k ∈ Finset.univ.erase i, actionTokenCost (σ k)
        ≥ ∑ _ ∈ Finset.univ.erase i, 25 := Finset.sum_le_sum (fun k _ => hCostGe k)
      _ = 25 * (params.agentCount - 1) := by
          rw [Finset.sum_const_nat (fun _ _ => rfl)]
          rw [Finset.card_erase_of_mem (Finset.mem_univ i)]
          rw [Finset.card_univ, Fintype.card_fin]
          ring
  -- T = 50 + rest ≥ 50 + 25(n-1) = 25n + 25 > 25n
  unfold totalTokens at hNoOF
  have := params.hPositive
  omega

-- ═══════════════════════════════════════════════════════════════════
-- Main theorem: Nash ⟹ all moderate
-- ═══════════════════════════════════════════════════════════════════

/-- Under tight budget (25n) with n ≤ 12, the all-moderate profile is
    the unique Nash equilibrium. -/
theorem nash_eq_allModerate (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12)
    (σ : Fin params.agentCount → AgentAction)
    (hNash : IsNashEquilibrium (fulcrumCoordinationGame params) σ) :
    ∀ i, σ i = AgentAction.moderate := by
  have hNoNC := no_noncompliant_in_nash params σ hNash
  have hNoOF := no_overflow_in_nash params hBudget hSmall σ hNash hNoNC
  have hNoCons := no_conservative_in_nash params hBudget σ hNash hNoNC hNoOF
  have hNoAgg := no_aggressive_without_overflow params hBudget σ hNoNC hNoCons hNoOF
  intro i
  cases hσ : σ i <;> simp_all

end Fulcrum.GameTheory
