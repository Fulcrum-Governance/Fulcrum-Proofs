/-
  Canonical exact constrained Price of Anarchy theorem.

  This module is deliberately independent of the legacy Real model and its
  correspondence proof.  The complete canonical claim uses structural sums
  and cross-addition order only.
-/

import Proofs.GameTheory.ExactNashUniqueness

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- Structural signed aggregation is determined by the two structural components. -/
theorem structuralSignedSum_components {n : Nat} (values : Fin n → SignedNat) :
    structuralSignedSum values =
      ⟨structuralSum SignedNat.pos values, structuralSum SignedNat.neg values⟩ := by
  induction n with
  | zero => rfl
  | succ n ih =>
      simp only [structuralSignedSum, structuralSum, SignedNat.add]
      rw [ih]

/-- Exact welfare has structural positive and negative components. -/
theorem exactWelfareNumerator_components (params : BudgetParams)
    (profile : ExactProfile params.agentCount) :
    exactWelfareNumerator params profile =
      ⟨params.agentCount * exactTotalQuality profile,
        params.agentCount * exactTotalPenalty profile +
          params.agentCount * exactOverflow params profile⟩ := by
  unfold exactWelfareNumerator
  rw [structuralSignedSum_components]
  refine congrArg₂ SignedNat.mk ?_ ?_
  · rw [structuralSum_pointwise SignedNat.pos
      (fun i => params.agentCount * exactActionQuality (profile i))
      (fun i => exactPayoffNumerator params profile i)
      (fun i : Fin params.agentCount => i) (fun _ => rfl)]
    rw [structuralSum_mul_left, structuralSum_index]
    unfold exactTotalQuality
    rfl
  · rw [structuralSum_pointwise SignedNat.neg
      (fun i => params.agentCount * exactActionPenalty (profile i) +
        exactOverflow params profile)
      (fun i => exactPayoffNumerator params profile i)
      (fun i : Fin params.agentCount => i) (fun _ => rfl)]
    rw [structuralSum_add]
    rw [structuralSum_mul_left]
    rw [structuralSum_index, structuralSum_const_fn]
    unfold exactTotalPenalty
    rw [Nat.mul_comm (exactOverflow params profile) params.agentCount]

/-- The exact action table satisfies the supporting welfare inequality. -/
theorem exactAction_supporting_inequality (action : AgentAction) :
    15 * exactActionQuality action + 100 ≤
      105 + 4 * exactActionCost action + 15 * exactActionPenalty action := by
  cases action <;> decide

/-- The supporting action inequality aggregates structurally over a roster. -/
theorem exactSupporting_inequality {n : Nat} (profile : ExactProfile n) :
    15 * exactTotalQuality profile + 100 * n ≤
      105 * n + 4 * exactTotalTokens profile + 15 * exactTotalPenalty profile := by
  have h := structuralSum_le
    (fun action => 15 * exactActionQuality action + 100)
    (fun action => 105 + 4 * exactActionCost action + 15 * exactActionPenalty action)
    profile exactAction_supporting_inequality
  rw [structuralSum_add, structuralSum_mul_left, structuralSum_const_fn] at h
  rw [structuralSum_add, structuralSum_add,
    structuralSum_const_fn, structuralSum_mul_left, structuralSum_mul_left] at h
  unfold exactTotalQuality exactTotalTokens exactTotalPenalty
  simpa only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h

/-- A feasible exact profile's quality is bounded by `7*n` plus its penalties. -/
theorem exactFeasible_quality_bound (params : BudgetParams)
    (profile : ExactProfile params.agentCount)
    (hFeasible : exactWithinBudget params profile)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    exactTotalQuality profile ≤
      7 * params.agentCount + exactTotalPenalty profile := by
  have hSupport := exactSupporting_inequality profile
  have hTokens : exactTotalTokens profile ≤ 25 * params.agentCount := by
    unfold exactWithinBudget at hFeasible
    rw [← hBudget]
    exact hFeasible
  have hScaledTokens : 4 * exactTotalTokens profile ≤ 100 * params.agentCount := by
    have h := Nat.mul_le_mul_left 4 hTokens
    calc
      4 * exactTotalTokens profile ≤ 4 * (25 * params.agentCount) := h
      _ = 100 * params.agentCount := by
        rw [← Nat.mul_assoc]
  have hUpper :
      105 * params.agentCount + 4 * exactTotalTokens profile +
          15 * exactTotalPenalty profile ≤
        105 * params.agentCount + 100 * params.agentCount +
          15 * exactTotalPenalty profile :=
    Nat.add_le_add_right
      (Nat.add_le_add_left hScaledTokens (105 * params.agentCount)) _
  have hCombined := le_trans hSupport hUpper
  have hCancelForm :
      100 * params.agentCount + 15 * exactTotalQuality profile ≤
        100 * params.agentCount +
          (105 * params.agentCount + 15 * exactTotalPenalty profile) := by
    simpa only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hCombined
  have hFifteen : 15 * exactTotalQuality profile ≤
      15 * (7 * params.agentCount + exactTotalPenalty profile) := by
    have hCancel := Nat.le_of_add_le_add_left hCancelForm
    calc
      15 * exactTotalQuality profile ≤
          105 * params.agentCount + 15 * exactTotalPenalty profile := hCancel
      _ = 15 * (7 * params.agentCount + exactTotalPenalty profile) := by
        rw [Nat.mul_add, ← Nat.mul_assoc]
  exact Nat.le_of_mul_le_mul_left hFifteen (by decide)

/-- All-moderate is feasible under the tight budget. -/
theorem exactAllModerate_feasible (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    exactWithinBudget params (exactAllModerate params.agentCount) := by
  unfold exactWithinBudget
  rw [exactAllModerate_totalTokens, hBudget]

/-- All-moderate attains exactly the encoded numerator corresponding to welfare `7*n`. -/
theorem exactAllModerate_welfareNumerator (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    exactWelfareNumerator params (exactAllModerate params.agentCount) =
      exactAllModerateWelfareNumerator params.agentCount := by
  rw [exactWelfareNumerator_components]
  have hOverflow := exactAllModerate_overflow_eq_zero params hBudget
  have hQuality : exactTotalQuality (exactAllModerate params.agentCount) =
      7 * params.agentCount := by
    unfold exactTotalQuality exactAllModerate
    simpa only [exactActionQuality] using
      (structuralSum_const_value exactActionQuality AgentAction.moderate
        params.agentCount)
  have hPenalty : exactTotalPenalty (exactAllModerate params.agentCount) = 0 := by
    unfold exactTotalPenalty exactAllModerate
    simpa only [exactActionPenalty, exactActionViolates, Bool.false_eq_true,
      if_false, Nat.zero_mul] using
      (structuralSum_const_value exactActionPenalty AgentAction.moderate
        params.agentCount)
  unfold exactAllModerateWelfareNumerator
  rw [hQuality, hPenalty, hOverflow]
  simp only [Nat.mul_zero, Nat.add_zero]
  refine congrArg₂ SignedNat.mk ?_ rfl
  change params.agentCount * (7 * params.agentCount) =
      7 * params.agentCount * params.agentCount
  rw [← Nat.mul_assoc, Nat.mul_comm params.agentCount 7]

/-- Every feasible exact profile is welfare-bounded by all-moderate. -/
theorem exactConstrained_welfare_optimal (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    ExactWelfareOptimal params := by
  intro profile hFeasible
  rw [exactWelfareNumerator_components]
  rw [exactAllModerate_welfareNumerator params hBudget]
  unfold exactAllModerateWelfareNumerator
  have hOverflow := exactOverflow_eq_zero_of_le params profile hFeasible
  have hQuality := exactFeasible_quality_bound params profile hFeasible hBudget
  have hScaled := Nat.mul_le_mul_left params.agentCount hQuality
  rw [Nat.mul_add] at hScaled
  change SignedNat.le
    ⟨params.agentCount * exactTotalQuality profile,
      params.agentCount * exactTotalPenalty profile +
        params.agentCount * exactOverflow params profile⟩
    ⟨7 * params.agentCount * params.agentCount, 0⟩
  unfold SignedNat.le
  rw [hOverflow]
  simp only [Nat.add_zero, Nat.mul_zero]
  calc
    params.agentCount * exactTotalQuality profile ≤
        params.agentCount * (7 * params.agentCount) +
          params.agentCount * exactTotalPenalty profile := hScaled
    _ = 7 * params.agentCount * params.agentCount +
          params.agentCount * exactTotalPenalty profile := by
      rw [← Nat.mul_assoc, Nat.mul_comm params.agentCount 7]

/-- Every exact Nash/feasible comparison satisfies the relational PoA bound at one. -/
theorem exactConstrained_poa_one (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ExactConstrainedPoABounded params 1 := by
  intro equilibrium hNash optimum hFeasible
  have hPointwise := exactNash_eq_allModerate params hBudget hSmall equilibrium hNash
  have hEquilibriumWelfare : exactWelfareNumerator params equilibrium =
      exactWelfareNumerator params (exactAllModerate params.agentCount) := by
    rw [exactWelfareNumerator_components, exactWelfareNumerator_components]
    have hTokens : exactTotalTokens equilibrium =
        exactTotalTokens (exactAllModerate params.agentCount) := by
      exact structuralSum_congr exactActionCost _ _ hPointwise
    have hQuality : exactTotalQuality equilibrium =
        exactTotalQuality (exactAllModerate params.agentCount) := by
      exact structuralSum_congr exactActionQuality _ _ hPointwise
    have hPenalty : exactTotalPenalty equilibrium =
        exactTotalPenalty (exactAllModerate params.agentCount) := by
      exact structuralSum_congr exactActionPenalty _ _ hPointwise
    refine congrArg₂ SignedNat.mk ?_ ?_
    · rw [hQuality]
    · rw [hPenalty]
      unfold exactOverflow
      rw [hTokens]
  rw [hEquilibriumWelfare]
  change exactWelfareNumerator params optimum ≤
    SignedNat.nsmul 1
      (exactWelfareNumerator params (exactAllModerate params.agentCount))
  have hOptimal := exactConstrained_welfare_optimal params hBudget optimum hFeasible
  simpa [SignedNat.nsmul] using hOptimal

/--
Canonical claim-complete constrained PoA theorem for every positive roster
`1..12` under the tight budget `B = 25*n`.
-/
theorem constrained_poa_exact (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ExactFullClaim params := by
  refine ⟨exactAllModerate_isNash params hBudget hSmall,
    exactNash_eq_allModerate params hBudget hSmall,
    exactAllModerate_feasible params hBudget,
    exactAllModerate_welfareNumerator params hBudget,
    exactConstrained_welfare_optimal params hBudget,
    exactConstrained_poa_one params hBudget hSmall⟩

end Fulcrum.GameTheory
