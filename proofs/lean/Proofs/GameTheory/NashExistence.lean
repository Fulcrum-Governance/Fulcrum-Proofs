/-
  Pure-Strategy Nash Equilibrium Existence for the Fulcrum Game

  Proves that the all-moderate strategy profile is a Nash equilibrium
  under tight budget constraints (budget = 25 * agentCount, n ≤ 12).

  Proof strategy: direct payoff comparison by case-splitting on deviations.
  The key mathematical fact for each case:
  - conservative deviation: quality drops 7→3, no overflow change → net loss of 4
  - aggressive deviation: quality +2 but overflow 25/n ≥ 25/12 > 2 → net loss
  - noncompliant deviation: penalty 20 overwhelms quality gain 1 → net loss ≥ 19

  NOTE: Some computational sub-goals (Finset.sum changes under Function.update
  over abstract Fin n) previously used placeholders. The mathematical argument is complete;
  the tactic engineering for abstract-n Finset.sum manipulation is pending.
  The mixed-strategy theorem (MixedNashExistence) provides a complementary
  proof path via Kakutani/Brouwer that covers all n without restriction.
-/

import Proofs.GameTheory.FulcrumGame
import Proofs.GameTheory.SumUpdateLemmas
import Mathlib.Data.Fintype.BigOperators

set_option autoImplicit false
set_option maxHeartbeats 800000

namespace Fulcrum.GameTheory

-- ═══════════════════════════════════════════════════════════
-- Helper: all-moderate profile
-- ═══════════════════════════════════════════════════════════

/-- The all-moderate profile: every agent plays moderate. -/
def allModerate (n : Nat) : Fin n → AgentAction := fun _ => AgentAction.moderate

/-- Total tokens when all play moderate is exactly 25n. -/
theorem allModerate_totalTokens (n : Nat) :
    totalTokens n (allModerate n) = 25 * n := by
  unfold totalTokens allModerate actionTokenCost
  simp [Finset.sum_const, Finset.card_univ, Fintype.card_fin]
  ring

-- ═══════════════════════════════════════════════════════════
-- Key lemma: totalTokens changes predictably under single-agent deviation
-- ═══════════════════════════════════════════════════════════

/-- When one agent in the all-moderate profile deviates to action `a`,
    total tokens change from 25n to 25n - 25 + cost(a). -/
lemma totalTokens_deviation (n : Nat) (i : Fin n) (a : AgentAction) :
    totalTokens n (Function.update (allModerate n) i a) =
    25 * n - 25 + actionTokenCost a := by
  unfold allModerate
  rw [totalTokens_update_allModerate]
  omega

-- ═══════════════════════════════════════════════════════════
-- Core theorem: noncompliant is strictly dominated
-- ═══════════════════════════════════════════════════════════

/-- Noncompliant is strictly dominated by moderate.
    The violation penalty (20) overwhelms the quality gain (8 vs 7 = +1).
    Mathematical fact: 7 - overflow₁ > 8 - 20 - overflow₂ since
    overflow₁ ≤ overflow₂ (moderate uses 15 fewer tokens) and 7 > -12. -/
theorem noncompliant_strictly_dominated
    (params : BudgetParams)
    (i : Fin params.agentCount) :
    ∀ profile : Fin params.agentCount → AgentAction,
    profile i = AgentAction.noncompliant →
    fulcrumPayoff params (Function.update profile i AgentAction.moderate) i
      > fulcrumPayoff params profile i := by
  intro profile hNoncomp
  set totalNew := totalTokens params.agentCount (Function.update profile i AgentAction.moderate)
    with hTotalNew
  set totalOld := totalTokens params.agentCount profile with hTotalOld
  have hTokensEq : totalNew + 40 = totalOld + 25 := by
    rw [hTotalNew, hTotalOld]
    simpa [hNoncomp, actionTokenCost] using
      totalTokens_update_general params.agentCount profile i AgentAction.moderate
  have hTokensLe : totalNew ≤ totalOld := by
    omega
  let overflowAmt : Nat → Nat :=
    fun t => if h : t > params.totalBudget then t - params.totalBudget else 0
  have hOverflowAmtLe : overflowAmt totalNew ≤ overflowAmt totalOld := by
    by_cases hOld : totalOld > params.totalBudget
    · by_cases hNew : totalNew > params.totalBudget
      · simp [overflowAmt, hOld, hNew]
        omega
      · simp [overflowAmt, hOld, hNew]
    · have hOldLe : totalOld ≤ params.totalBudget := le_of_not_gt hOld
      have hNewLe : totalNew ≤ params.totalBudget := le_trans hTokensLe hOldLe
      have hNew : ¬ totalNew > params.totalBudget := by
        omega
      simp [overflowAmt, hOld, hNew]
  have hn_pos : (0 : ℝ) < params.agentCount := by
    exact_mod_cast params.hPositive
  have hOverflowLe :
      ((overflowAmt totalNew : ℝ) / (params.agentCount : ℝ)) ≤
        ((overflowAmt totalOld : ℝ) / (params.agentCount : ℝ)) := by
    exact div_le_div_of_nonneg_right (by exact_mod_cast hOverflowAmtLe) (le_of_lt hn_pos)
  have hOverflowEq (t : Nat) :
      (if (t : ℝ) > (params.totalBudget : ℝ)
        then ((t : ℝ) - (params.totalBudget : ℝ)) / (params.agentCount : ℝ)
        else 0) =
      ((overflowAmt t : ℝ) / (params.agentCount : ℝ)) := by
    by_cases h : t > params.totalBudget
    · have hReal : (t : ℝ) > (params.totalBudget : ℝ) := by
        exact_mod_cast h
      rw [if_pos hReal]
      simp [overflowAmt, h]
      rw [Nat.cast_sub (Nat.le_of_lt h)]
    · have hReal : ¬ ((t : ℝ) > (params.totalBudget : ℝ)) := by
        exact_mod_cast h
      rw [if_neg hReal]
      simp [overflowAmt, h]
  have hNewPayoff :
      fulcrumPayoff params (Function.update profile i AgentAction.moderate) i =
        7 - ((overflowAmt totalNew : ℝ) / (params.agentCount : ℝ)) := by
    unfold fulcrumPayoff
    dsimp
    rw [show (if ((totalTokens params.agentCount (Function.update profile i AgentAction.moderate) : ℝ) >
          (params.totalBudget : ℝ))
        then ((totalTokens params.agentCount (Function.update profile i AgentAction.moderate) : ℝ) -
          (params.totalBudget : ℝ)) / (params.agentCount : ℝ)
        else 0) = ((overflowAmt totalNew : ℝ) / (params.agentCount : ℝ)) by
        rw [← hTotalNew]
        exact hOverflowEq totalNew]
    simp [Function.update_self, actionQuality, actionViolates]
  have hOldPayoff :
      fulcrumPayoff params profile i =
        8 - 20 - ((overflowAmt totalOld : ℝ) / (params.agentCount : ℝ)) := by
    unfold fulcrumPayoff
    dsimp
    rw [show (if ((totalTokens params.agentCount profile : ℝ) > (params.totalBudget : ℝ))
        then ((totalTokens params.agentCount profile : ℝ) - (params.totalBudget : ℝ)) /
          (params.agentCount : ℝ)
        else 0) = ((overflowAmt totalOld : ℝ) / (params.agentCount : ℝ)) by
        rw [← hTotalOld]
        exact hOverflowEq totalOld]
    simp [hNoncomp, actionQuality, actionViolates, violationPenalty]
  rw [hNewPayoff, hOldPayoff]
  nlinarith

-- ═══════════════════════════════════════════════════════════
-- Core theorem: all-moderate is Nash under tight budget
-- ═══════════════════════════════════════════════════════════

/-- The fulcrum payoff for all-moderate under tight budget equals 7:
    quality(moderate) = 7, no penalty, no overflow. -/
lemma allModerate_payoff_eq_seven (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (i : Fin params.agentCount) :
    fulcrumPayoff params (allModerate params.agentCount) i = 7 := by
  unfold fulcrumPayoff
  rw [allModerate_totalTokens]
  simp [allModerate, hBudget, actionQuality, actionViolates]

/-- Under tight budget (= 25n) with n ≤ 12, the all-moderate profile is
    a Nash equilibrium. No agent can profitably deviate.

    The bound n ≤ 12 ensures aggressive deviation is unprofitable:
    aggressive adds 25 tokens of overflow shared among n agents,
    costing 25/n per agent. For n ≤ 12, 25/n > 2 = quality gain from
    aggressive over moderate. For n ≥ 13, this reverses — see the
    mixed-strategy theorem for the general case.

    Mathematical proof per deviation case:
    - moderate→moderate: identity, no change
    - moderate→conservative: payoff = 3 < 7 (quality loss, no overflow)
    - moderate→aggressive: payoff = 9 - 25/n < 7 when n ≤ 12
    - moderate→noncompliant: payoff = 8 - 20 - 15/n < 7 (penalty dominates) -/
theorem moderate_is_nash_equilibrium
    (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    IsNashEquilibrium (fulcrumCoordinationGame params)
      (fun _ => AgentAction.moderate) := by
  intro i s'
  change fulcrumPayoff params (allModerate params.agentCount) i ≥
    fulcrumPayoff params (Function.update (allModerate params.agentCount) i s') i
  have h_base := allModerate_payoff_eq_seven params hBudget i
  rw [h_base]
  cases s' with
  | moderate =>
    rw [show Function.update (allModerate params.agentCount) i AgentAction.moderate =
        allModerate params.agentCount by
          simpa [allModerate] using
            (Function.update_eq_self i (allModerate params.agentCount))]
    rw [h_base]
  | conservative =>
    have hTokens :
        totalTokens params.agentCount
          (Function.update (allModerate params.agentCount) i AgentAction.conservative) =
            10 + 25 * (params.agentCount - 1) := by
      simpa [allModerate, actionTokenCost] using
        totalTokens_update_allModerate params.agentCount i AgentAction.conservative
    have hNoOverflowNat : 10 + 25 * (params.agentCount - 1) ≤ params.totalBudget := by
      rw [hBudget]
      have hpos := params.hPositive
      omega
    have hPayoff :
        fulcrumPayoff params
          (Function.update (allModerate params.agentCount) i AgentAction.conservative) i = 3 := by
      unfold fulcrumPayoff
      rw [hTokens]
      dsimp
      have hNoOverflow :
          ¬ ((((10 + 25 * (params.agentCount - 1) : Nat) : ℝ) > (params.totalBudget : ℝ))) := by
        exact not_lt.mpr (by exact_mod_cast hNoOverflowNat)
      rw [if_neg hNoOverflow]
      norm_num [Function.update_self, actionQuality, actionViolates]
    rw [hPayoff]
    norm_num
  | aggressive =>
    have hTokens :
        totalTokens params.agentCount
          (Function.update (allModerate params.agentCount) i AgentAction.aggressive) =
            50 + 25 * (params.agentCount - 1) := by
      simpa [allModerate, actionTokenCost] using
        totalTokens_update_allModerate params.agentCount i AgentAction.aggressive
    have hOverflowNat : params.totalBudget < 50 + 25 * (params.agentCount - 1) := by
      rw [hBudget]
      have hpos := params.hPositive
      omega
    have hn_pos : (0 : ℝ) < params.agentCount := by
      exact_mod_cast params.hPositive
    have hDivGtTwo : (2 : ℝ) < 25 / (params.agentCount : ℝ) := by
      have hn_le : (params.agentCount : ℝ) ≤ 12 := by
        exact_mod_cast hSmall
      have hmul : (2 : ℝ) * params.agentCount < 25 := by
        nlinarith
      exact (lt_div_iff₀ hn_pos).2 hmul
    have hPayoff :
        fulcrumPayoff params
          (Function.update (allModerate params.agentCount) i AgentAction.aggressive) i =
            9 - 25 / (params.agentCount : ℝ) := by
      unfold fulcrumPayoff
      rw [hTokens]
      dsimp
      have hOverflow :
          (((50 + 25 * (params.agentCount - 1) : Nat) : ℝ) > (params.totalBudget : ℝ)) := by
        exact_mod_cast hOverflowNat
      rw [if_pos hOverflow]
      have hEqNat : 50 + 25 * (params.agentCount - 1) = 25 * params.agentCount + 25 := by
        have hpos := params.hPositive
        omega
      have hOverflowValue :
          ((((50 + 25 * (params.agentCount - 1) : Nat) : ℝ) - (params.totalBudget : ℝ)) /
            (params.agentCount : ℝ)) = 25 / (params.agentCount : ℝ) := by
        rw [show (((50 + 25 * (params.agentCount - 1) : Nat) : ℝ) =
            ((25 * params.agentCount + 25 : Nat) : ℝ)) by exact_mod_cast hEqNat]
        rw [hBudget]
        have hn_ne : (params.agentCount : ℝ) ≠ 0 := by
          positivity
        field_simp [hn_ne]
        norm_num
      rw [hOverflowValue]
      norm_num [Function.update_self, actionQuality, actionViolates]
    rw [hPayoff]
    nlinarith
  | noncompliant =>
    have hTokens :
        totalTokens params.agentCount
          (Function.update (allModerate params.agentCount) i AgentAction.noncompliant) =
            40 + 25 * (params.agentCount - 1) := by
      simpa [allModerate, actionTokenCost] using
        totalTokens_update_allModerate params.agentCount i AgentAction.noncompliant
    have hOverflowNat : params.totalBudget < 40 + 25 * (params.agentCount - 1) := by
      rw [hBudget]
      have hpos := params.hPositive
      omega
    have hn_pos : (0 : ℝ) < params.agentCount := by
      exact_mod_cast params.hPositive
    have hDivPos : (0 : ℝ) < 15 / (params.agentCount : ℝ) := by
      exact div_pos (by norm_num) hn_pos
    have hPayoff :
        fulcrumPayoff params
          (Function.update (allModerate params.agentCount) i AgentAction.noncompliant) i =
            8 - 20 - 15 / (params.agentCount : ℝ) := by
      unfold fulcrumPayoff
      rw [hTokens]
      dsimp
      have hOverflow :
          (((40 + 25 * (params.agentCount - 1) : Nat) : ℝ) > (params.totalBudget : ℝ)) := by
        exact_mod_cast hOverflowNat
      rw [if_pos hOverflow]
      have hEqNat : 40 + 25 * (params.agentCount - 1) = 25 * params.agentCount + 15 := by
        have hpos := params.hPositive
        omega
      have hOverflowValue :
          ((((40 + 25 * (params.agentCount - 1) : Nat) : ℝ) - (params.totalBudget : ℝ)) /
            (params.agentCount : ℝ)) = 15 / (params.agentCount : ℝ) := by
        rw [show (((40 + 25 * (params.agentCount - 1) : Nat) : ℝ) =
            ((25 * params.agentCount + 15 : Nat) : ℝ)) by exact_mod_cast hEqNat]
        rw [hBudget]
        have hn_ne : (params.agentCount : ℝ) ≠ 0 := by
          positivity
        field_simp [hn_ne]
        norm_num
      rw [hOverflowValue]
      norm_num [Function.update_self, actionQuality, actionViolates, violationPenalty]
    rw [hPayoff]
    nlinarith

/-- The Fulcrum coordination game admits at least one pure-strategy
    Nash equilibrium under tight budget with bounded team size. -/
theorem fulcrum_pure_nash_exists
    (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ∃ σ : StrategyProfile (fulcrumCoordinationGame params),
      IsNashEquilibrium (fulcrumCoordinationGame params) σ :=
  ⟨fun _ => AgentAction.moderate, moderate_is_nash_equilibrium params hBudget hSmall⟩

end Fulcrum.GameTheory
