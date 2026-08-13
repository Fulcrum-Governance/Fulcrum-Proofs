/-
  Machine-checked correspondence between the canonical exact coordination
  game and the legacy Real-valued model.

  This module is deliberately downstream of both developments.  Nothing here
  enters the dependency closure of `constrained_poa_exact`.
-/

import Proofs.GameTheory.CoordinationEfficiency
import Mathlib.Algebra.BigOperators.Fin

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-! ## 1. Action-data identity -/

theorem exactActionCost_eq_actionTokenCost (action : AgentAction) :
    exactActionCost action = actionTokenCost action := by
  cases action <;> rfl

theorem exactActionQuality_eq_actionQuality (action : AgentAction) :
    exactActionQuality action = actionQuality action := by
  cases action <;> rfl

theorem exactActionViolates_eq_actionViolates (action : AgentAction) :
    exactActionViolates action = actionViolates action := by
  cases action <;> rfl

theorem exactViolationPenalty_eq_violationPenalty :
    exactViolationPenalty = violationPenalty := rfl

theorem exactActionPenalty_eq_legacyPenalty (action : AgentAction) :
    exactActionPenalty action =
      if actionViolates action then violationPenalty else 0 := by
  cases action <;> rfl

/-! ## 2. Structural roster coverage -/

theorem correspondenceRoster_length {n : Nat} (profile : ExactProfile n) :
    (exactRoster profile).length = n :=
  exactRoster_length profile

theorem correspondenceRoster_get {n : Nat} (profile : ExactProfile n)
    (i : Fin n) :
    (exactRoster profile)[i.val]'(by simpa [exactRoster] using i.isLt) = profile i :=
  exactRoster_get profile i

/-! ## 3. Structural token-total identity -/

theorem structuralSum_eq_finsetSum {α : Type} (f : α → Nat) {n : Nat}
    (profile : Fin n → α) :
    structuralSum f profile = ∑ i : Fin n, f (profile i) := by
  induction n with
  | zero => simp [structuralSum]
  | succ n ih =>
      rw [Fin.sum_univ_succ]
      simp only [structuralSum]
      rw [ih]

theorem exactTotalTokens_eq_totalTokens {n : Nat} (profile : ExactProfile n) :
    exactTotalTokens profile = totalTokens n profile := by
  unfold exactTotalTokens totalTokens
  rw [structuralSum_eq_finsetSum]
  apply Finset.sum_congr rfl
  intro i _
  exact exactActionCost_eq_actionTokenCost (profile i)

/-! ## 4. Signed interpretation and cross-addition order -/

/-- Real interpretation of a signed-natural numerator over a denominator. -/
noncomputable def signedNatValue (denominator : Nat) (value : SignedNat) : Real :=
  ((value.pos : Real) - (value.neg : Real)) / (denominator : Real)

theorem signedNatValue_add (denominator : Nat) (x y : SignedNat) :
    signedNatValue denominator (SignedNat.add x y) =
      signedNatValue denominator x + signedNatValue denominator y := by
  unfold signedNatValue SignedNat.add
  push_cast
  ring

theorem signedNat_le_iff_real_le (denominator : Nat) (hPositive : 0 < denominator)
    (x y : SignedNat) :
    x ≤ y ↔ signedNatValue denominator x ≤ signedNatValue denominator y := by
  have hDenominator : (0 : Real) < denominator := by exact_mod_cast hPositive
  change SignedNat.le x y ↔
    signedNatValue denominator x ≤ signedNatValue denominator y
  unfold signedNatValue
  rw [div_le_div_iff_of_pos_right hDenominator]
  unfold SignedNat.le
  constructor
  · intro h
    have hCast : (x.pos : Real) + y.neg ≤ y.pos + x.neg := by exact_mod_cast h
    linarith
  · intro h
    have hCast : (x.pos : Real) + y.neg ≤ y.pos + x.neg := by linarith
    exact_mod_cast hCast

/-! ## 5. Exact payoff values, including both overflow branches -/

theorem exactOverflow_share_eq_legacy (params : BudgetParams)
    (profile : ExactProfile params.agentCount) :
    (exactOverflow params profile : Real) / params.agentCount =
      if (totalTokens params.agentCount profile : Real) > params.totalBudget then
        ((totalTokens params.agentCount profile : Real) - params.totalBudget) /
          params.agentCount
      else 0 := by
  unfold exactOverflow
  rw [exactTotalTokens_eq_totalTokens]
  by_cases hOverflow : params.totalBudget < totalTokens params.agentCount profile
  · have hReal : (params.totalBudget : Real) <
        totalTokens params.agentCount profile := by exact_mod_cast hOverflow
    rw [if_pos hReal, Nat.cast_sub (Nat.le_of_lt hOverflow)]
  · have hLe : totalTokens params.agentCount profile ≤ params.totalBudget :=
      Nat.le_of_not_gt hOverflow
    have hReal : ¬ ((totalTokens params.agentCount profile : Real) >
        params.totalBudget) := by exact_mod_cast (not_lt.mpr hLe)
    rw [if_neg hReal, Nat.sub_eq_zero_of_le hLe]
    norm_num

theorem exactPayoff_value (params : BudgetParams)
    (profile : ExactProfile params.agentCount) (i : Fin params.agentCount) :
    signedNatValue params.agentCount (exactPayoffNumerator params profile i) =
      fulcrumPayoff params profile i := by
  have hCount : (params.agentCount : Real) ≠ 0 := by
    exact_mod_cast (Nat.ne_of_gt params.hPositive)
  unfold signedNatValue exactPayoffNumerator fulcrumPayoff
  rw [exactActionQuality_eq_actionQuality]
  rw [exactActionPenalty_eq_legacyPenalty]
  simp only [Nat.cast_mul, Nat.cast_add, Nat.cast_ite, Nat.cast_zero]
  rw [← exactOverflow_share_eq_legacy]
  field_simp [hCount]
  ring

theorem exactPayoff_value_noOverflow (params : BudgetParams)
    (profile : ExactProfile params.agentCount) (i : Fin params.agentCount)
    (hFeasible : exactTotalTokens profile ≤ params.totalBudget) :
    signedNatValue params.agentCount (exactPayoffNumerator params profile i) =
      (actionQuality (profile i) : Real) -
        (if actionViolates (profile i) then (violationPenalty : Real) else 0) := by
  rw [exactPayoff_value]
  simp only [fulcrumPayoff]
  have hLegacy : totalTokens params.agentCount profile ≤ params.totalBudget := by
    rw [← exactTotalTokens_eq_totalTokens]
    exact hFeasible
  have hReal : ¬ ((totalTokens params.agentCount profile : Real) >
      params.totalBudget) := by exact_mod_cast (not_lt.mpr hLegacy)
  rw [if_neg hReal]
  ring

theorem exactPayoff_value_overflow (params : BudgetParams)
    (profile : ExactProfile params.agentCount) (i : Fin params.agentCount)
    (hOverflow : params.totalBudget < exactTotalTokens profile) :
    signedNatValue params.agentCount (exactPayoffNumerator params profile i) =
      (actionQuality (profile i) : Real) -
        (if actionViolates (profile i) then (violationPenalty : Real) else 0) -
        ((totalTokens params.agentCount profile : Real) - params.totalBudget) /
          params.agentCount := by
  rw [exactPayoff_value]
  simp only [fulcrumPayoff]
  have hLegacy : params.totalBudget < totalTokens params.agentCount profile := by
    rw [← exactTotalTokens_eq_totalTokens]
    exact hOverflow
  have hReal : (params.totalBudget : Real) <
      totalTokens params.agentCount profile := by exact_mod_cast hLegacy
  rw [if_pos hReal]

/-! ## 6. Bidirectional payoff-order correspondence -/

theorem exactPayoff_le_iff_realPayoff_le (params : BudgetParams)
    (profile₁ profile₂ : ExactProfile params.agentCount)
    (i : Fin params.agentCount) :
    exactPayoffNumerator params profile₁ i ≤ exactPayoffNumerator params profile₂ i ↔
      fulcrumPayoff params profile₁ i ≤ fulcrumPayoff params profile₂ i := by
  rw [signedNat_le_iff_real_le params.agentCount params.hPositive]
  rw [exactPayoff_value, exactPayoff_value]

/-! ## 7. Unilateral-deviation/update identity -/

theorem exactUpdate_eq_functionUpdate {n : Nat} (profile : ExactProfile n)
    (i : Fin n) (action : AgentAction) :
    exactUpdate profile i action = Function.update profile i action := rfl

theorem correspondenceUpdate_changed {n : Nat} (profile : ExactProfile n)
    (i : Fin n) (action : AgentAction) :
    exactUpdate profile i action i = action :=
  exactUpdate_same profile i action

theorem correspondenceUpdate_unchanged {n : Nat} (profile : ExactProfile n)
    (i j : Fin n) (action : AgentAction) (h : j ≠ i) :
    exactUpdate profile i action j = profile j :=
  exactUpdate_of_ne profile i j action h

/-! ## 8. Budget-feasibility equivalence -/

theorem exactWithinBudget_iff_withinBudget (params : BudgetParams)
    (profile : ExactProfile params.agentCount) :
    exactWithinBudget params profile ↔ withinBudget params profile := by
  unfold exactWithinBudget withinBudget
  rw [exactTotalTokens_eq_totalTokens]

/-! ## 9. Bidirectional Nash-predicate equivalence -/

theorem exactIsNash_iff_isNashEquilibrium (params : BudgetParams)
    (profile : ExactProfile params.agentCount) :
    ExactIsNash params profile ↔
      IsNashEquilibrium (fulcrumCoordinationGame params) profile := by
  unfold ExactIsNash IsNashEquilibrium IsBestResponse fulcrumCoordinationGame
  constructor
  · intro h i action
    exact (exactPayoff_le_iff_realPayoff_le params
      (exactUpdate profile i action) profile i).mp (h i action)
  · intro h i action
    exact (exactPayoff_le_iff_realPayoff_le params
      (exactUpdate profile i action) profile i).mpr (h i action)

/-! ## 10. Exact welfare value and order correspondence -/

theorem structuralSignedSum_value (denominator : Nat) {n : Nat}
    (values : Fin n → SignedNat) :
    signedNatValue denominator (structuralSignedSum values) =
      ∑ i : Fin n, signedNatValue denominator (values i) := by
  induction n with
  | zero => simp [structuralSignedSum, signedNatValue, SignedNat.zero]
  | succ n ih =>
      rw [Fin.sum_univ_succ]
      simp only [structuralSignedSum]
      rw [signedNatValue_add, ih]

theorem exactWelfare_value (params : BudgetParams)
    (profile : ExactProfile params.agentCount) :
    signedNatValue params.agentCount (exactWelfareNumerator params profile) =
      socialWelfare (fulcrumCoordinationGame params) profile := by
  unfold exactWelfareNumerator socialWelfare fulcrumCoordinationGame
  rw [structuralSignedSum_value]
  apply Finset.sum_congr rfl
  intro i _
  exact exactPayoff_value params profile i

theorem exactWelfare_le_iff_realWelfare_le (params : BudgetParams)
    (profile₁ profile₂ : ExactProfile params.agentCount) :
    exactWelfareNumerator params profile₁ ≤ exactWelfareNumerator params profile₂ ↔
      socialWelfare (fulcrumCoordinationGame params) profile₁ ≤
        socialWelfare (fulcrumCoordinationGame params) profile₂ := by
  rw [signedNat_le_iff_real_le params.agentCount params.hPositive]
  rw [exactWelfare_value, exactWelfare_value]

/-! ## 11. All-moderate profile, cost, feasibility, payoff, and welfare -/

theorem exactAllModerate_profile (n : Nat) (i : Fin n) :
    exactAllModerate n i = allModerate n i := rfl

theorem exactAllModerate_cost (n : Nat) :
    exactTotalTokens (exactAllModerate n) = 25 * n ∧
      totalTokens n (allModerate n) = 25 * n := by
  exact ⟨exactAllModerate_totalTokens n, allModerate_totalTokens n⟩

theorem exactAllModerate_feasibility_iff (params : BudgetParams) :
    exactWithinBudget params (exactAllModerate params.agentCount) ↔
      withinBudget params (allModerate params.agentCount) :=
  exactWithinBudget_iff_withinBudget params (exactAllModerate params.agentCount)

theorem exactAllModerate_feasibility (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    exactWithinBudget params (exactAllModerate params.agentCount) ∧
      withinBudget params (allModerate params.agentCount) := by
  have hExact := exactAllModerate_feasible params hBudget
  exact ⟨hExact, (exactAllModerate_feasibility_iff params).mp hExact⟩

theorem exactAllModerate_payoff (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (i : Fin params.agentCount) :
    exactPayoffNumerator params (exactAllModerate params.agentCount) i =
        ⟨7 * params.agentCount, 0⟩ ∧
      signedNatValue params.agentCount
          (exactPayoffNumerator params (exactAllModerate params.agentCount) i) = 7 ∧
      fulcrumPayoff params (allModerate params.agentCount) i = 7 := by
  have hExact := exactAllModerate_payoffNumerator params hBudget i
  have hReal := allModerate_payoff_eq_seven params hBudget i
  exact ⟨hExact, by rw [exactPayoff_value]; exact hReal, hReal⟩

theorem exactAllModerate_welfare (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    exactWelfareNumerator params (exactAllModerate params.agentCount) =
        exactAllModerateWelfareNumerator params.agentCount ∧
      signedNatValue params.agentCount
          (exactWelfareNumerator params (exactAllModerate params.agentCount)) =
        7 * params.agentCount ∧
      socialWelfare (fulcrumCoordinationGame params)
          (allModerate params.agentCount) = 7 * params.agentCount := by
  have hExact := exactAllModerate_welfareNumerator params hBudget
  have hReal := allModerate_welfare params hBudget
  refine ⟨hExact, ?_, hReal⟩
  rw [exactWelfare_value]
  exact hReal

/-! ## 12. All-moderate Nash existence and pointwise uniqueness -/

theorem exactAllModerate_nash_iff_real (params : BudgetParams) :
    ExactIsNash params (exactAllModerate params.agentCount) ↔
      IsNashEquilibrium (fulcrumCoordinationGame params)
        (allModerate params.agentCount) :=
  exactIsNash_iff_isNashEquilibrium params (exactAllModerate params.agentCount)

theorem exactNashUniqueness_iff_real (params : BudgetParams) :
    (∀ profile, ExactIsNash params profile →
      ∀ i, profile i = AgentAction.moderate) ↔
    (∀ profile, IsNashEquilibrium (fulcrumCoordinationGame params) profile →
      ∀ i, profile i = AgentAction.moderate) := by
  constructor
  · intro h profile hNash
    exact h profile ((exactIsNash_iff_isNashEquilibrium params profile).mpr hNash)
  · intro h profile hNash
    exact h profile ((exactIsNash_iff_isNashEquilibrium params profile).mp hNash)

theorem exactAllModerate_existence_and_uniqueness (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ExactIsNash params (exactAllModerate params.agentCount) ∧
      (∀ profile, ExactIsNash params profile →
        ∀ i, profile i = AgentAction.moderate) :=
  ⟨exactAllModerate_isNash params hBudget hSmall,
    exactNash_eq_allModerate params hBudget hSmall⟩

/-! ## 13. Equivalence of the complete six-clause claims -/

def RealWelfareOptimal (params : BudgetParams) : Prop :=
  ∀ profile, withinBudget params profile →
    socialWelfare (fulcrumCoordinationGame params) profile ≤
      socialWelfare (fulcrumCoordinationGame params)
        (allModerate params.agentCount)

def RealFullClaim (params : BudgetParams) : Prop :=
  IsNashEquilibrium (fulcrumCoordinationGame params)
      (allModerate params.agentCount) ∧
  (∀ profile, IsNashEquilibrium (fulcrumCoordinationGame params) profile →
    ∀ i, profile i = AgentAction.moderate) ∧
  withinBudget params (allModerate params.agentCount) ∧
  socialWelfare (fulcrumCoordinationGame params)
      (allModerate params.agentCount) = 7 * params.agentCount ∧
  RealWelfareOptimal params ∧
  ConstrainedPriceOfAnarchyBounded
    (fulcrumCoordinationGame params)
    (fun profile => withinBudget params profile) 1

theorem realFullClaim (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    RealFullClaim params := by
  refine ⟨moderate_is_nash_equilibrium params hBudget hSmall,
    nash_eq_allModerate params hBudget hSmall,
    ?_, allModerate_welfare params hBudget, ?_,
    constrained_poa_exact_real_compat params hBudget hSmall⟩
  · unfold withinBudget
    rw [allModerate_totalTokens, hBudget]
  · intro profile hFeasible
    calc
      socialWelfare (fulcrumCoordinationGame params) profile ≤
          7 * params.agentCount :=
        constrained_welfare_optimal params hBudget hSmall profile hFeasible
      _ = socialWelfare (fulcrumCoordinationGame params)
          (allModerate params.agentCount) :=
        (allModerate_welfare params hBudget).symm

theorem exactFullClaim_iff_realFullClaim (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ExactFullClaim params ↔ RealFullClaim params := by
  constructor
  · intro _
    exact realFullClaim params hBudget hSmall
  · intro _
    exact constrained_poa_exact params hBudget hSmall

/-! ## 14. Complete positive `1..12` domain coverage -/

def ExactCompleteDomain : Prop :=
  ∀ params : BudgetParams,
    params.totalBudget = 25 * params.agentCount →
    params.agentCount ≤ 12 →
    ExactFullClaim params

def RealCompleteDomain : Prop :=
  ∀ params : BudgetParams,
    params.totalBudget = 25 * params.agentCount →
    params.agentCount ≤ 12 →
    RealFullClaim params

theorem exactCompleteDomain_iff_realCompleteDomain :
    ExactCompleteDomain ↔ RealCompleteDomain := by
  constructor
  · intro _ params hBudget hSmall
    exact realFullClaim params hBudget hSmall
  · intro _ params hBudget hSmall
    exact constrained_poa_exact params hBudget hSmall

end Fulcrum.GameTheory
