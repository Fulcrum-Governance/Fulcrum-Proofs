/-
  Exact all-moderate payoff and pure Nash existence.
-/

import Proofs.GameTheory.ExactSumUpdateLemmas

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- Under the tight budget, all-moderate has no overflow. -/
theorem exactAllModerate_overflow_eq_zero (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    exactOverflow params (exactAllModerate params.agentCount) = 0 := by
  apply exactOverflow_eq_zero_of_le
  rw [exactAllModerate_totalTokens, hBudget]

/-- Every agent receives the exact numerator `7*n` at all-moderate. -/
theorem exactAllModerate_payoffNumerator (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (i : Fin params.agentCount) :
    exactPayoffNumerator params (exactAllModerate params.agentCount) i =
      ⟨7 * params.agentCount, 0⟩ := by
  have hOverflow := exactAllModerate_overflow_eq_zero params hBudget
  simp [exactPayoffNumerator, exactAllModerate, exactActionQuality,
    exactActionPenalty, exactActionViolates, hOverflow, Nat.mul_comm]

/-- Replacing one all-moderate action by aggressive creates exactly 25 overflow tokens. -/
theorem exactAllModerate_aggressive_overflow (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (i : Fin params.agentCount) :
    exactOverflow params
        (exactUpdate (exactAllModerate params.agentCount) i .aggressive) = 25 := by
  have hUpdate := exactTotalTokens_update_general
    (exactAllModerate params.agentCount) i AgentAction.aggressive
  have hTotal : exactTotalTokens
      (exactUpdate (exactAllModerate params.agentCount) i .aggressive) =
        25 * params.agentCount + 25 := by
    rw [exactAllModerate_totalTokens] at hUpdate
    change exactTotalTokens
        (exactUpdate (exactAllModerate params.agentCount) i .aggressive) + 25 =
      25 * params.agentCount + 50 at hUpdate
    have hFifty : 50 = 25 + 25 := rfl
    rw [hFifty, ← Nat.add_assoc] at hUpdate
    exact Nat.add_right_cancel hUpdate
  unfold exactOverflow
  rw [hTotal, hBudget]
  exact Nat.add_sub_cancel_left _ _

/-- The arithmetic inequality that makes aggressive deviation unprofitable through `n = 12`. -/
theorem exactAggressive_deviation_bound {n : Nat} (hSmall : n ≤ 12) :
    9 * n ≤ 7 * n + 25 := by
  have hTwo : 2 * n ≤ 2 * 12 := Nat.mul_le_mul_left 2 hSmall
  have hTwentyFive : 2 * n ≤ 25 := le_trans hTwo (by decide)
  have hAdd := Nat.add_le_add_left hTwentyFive (7 * n)
  rw [← Nat.add_mul] at hAdd
  exact hAdd

/-- All-moderate is a pure Nash equilibrium for every positive `n ≤ 12`. -/
theorem exactAllModerate_isNash (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ExactIsNash params (exactAllModerate params.agentCount) := by
  intro i action
  have hCurrent := exactAllModerate_payoffNumerator params hBudget i
  cases action with
  | conservative =>
      rw [hCurrent]
      simp only [exactPayoffNumerator, exactUpdate_same, exactActionQuality,
        exactActionPenalty, exactActionViolates, Bool.false_eq_true, if_false]
      have hThree : 3 * params.agentCount ≤ 7 * params.agentCount :=
        Nat.mul_le_mul_right params.agentCount (by decide)
      simpa [Nat.mul_comm] using le_trans hThree
        (Nat.le_add_right (7 * params.agentCount) _)
  | moderate =>
      have hUpdate := exactTotalTokens_update_general
        (exactAllModerate params.agentCount) i AgentAction.moderate
      have hTotal : exactTotalTokens
          (exactUpdate (exactAllModerate params.agentCount) i .moderate) =
            25 * params.agentCount := by
        rw [exactAllModerate_totalTokens] at hUpdate
        change exactTotalTokens
            (exactUpdate (exactAllModerate params.agentCount) i .moderate) + 25 =
          25 * params.agentCount + 25 at hUpdate
        exact Nat.add_right_cancel hUpdate
      have hOverflow : exactOverflow params
          (exactUpdate (exactAllModerate params.agentCount) i .moderate) = 0 := by
        unfold exactOverflow
        rw [hTotal, hBudget]
        exact Nat.sub_self _
      rw [hCurrent]
      simp only [exactPayoffNumerator, exactUpdate_same, exactActionQuality,
        exactActionPenalty, exactActionViolates, Bool.false_eq_true, if_false,
        hOverflow, Nat.mul_zero, Nat.add_zero]
      change params.agentCount * 7 + 0 ≤ 7 * params.agentCount + 0
      rw [Nat.mul_comm]
  | aggressive =>
      rw [hCurrent]
      simp only [exactPayoffNumerator, exactUpdate_same, exactActionQuality,
        exactActionPenalty, exactActionViolates, Bool.false_eq_true, if_false]
      rw [exactAllModerate_aggressive_overflow params hBudget i]
      simpa [Nat.mul_comm] using exactAggressive_deviation_bound hSmall
  | noncompliant =>
      rw [hCurrent]
      simp only [exactPayoffNumerator, exactUpdate_same, exactActionQuality,
        exactActionPenalty, exactActionViolates, exactViolationPenalty,
        if_pos rfl]
      have hEight : 8 * params.agentCount ≤ 27 * params.agentCount :=
        Nat.mul_le_mul_right params.agentCount (by decide)
      have hExpand : 27 * params.agentCount =
          7 * params.agentCount + params.agentCount * 20 := by
        rw [Nat.mul_comm params.agentCount 20, ← Nat.add_mul]
      rw [hExpand] at hEight
      simpa [Nat.mul_comm, Nat.add_assoc] using le_trans hEight
        (Nat.le_add_right
          (7 * params.agentCount + params.agentCount * 20) _)

end Fulcrum.GameTheory
