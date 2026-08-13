/-
  Price of Anarchy Bound for the Fulcrum Coordination Game

  Proves that the Price of Anarchy (PoA) for the Fulcrum game is bounded,
  meaning the coordination loss from self-interested agent behavior is limited.

  The PoA measures: optimal_welfare / worst_equilibrium_welfare.
  A PoA of 1 means equilibria are optimal; higher means more waste.

  For the Fulcrum game under tight budget, the all-moderate equilibrium
  achieves welfare 7n. The optimal profile (all-aggressive without overflow)
  would achieve welfare 9n but requires budget 50n. Under tight budget (25n),
  all-aggressive overflows, reducing welfare. The PoA bound captures this.
-/

import Proofs.GameTheory.FulcrumGame
import Proofs.GameTheory.NashExistence
import Proofs.GameTheory.NashUniqueness
import Proofs.GameTheory.SumUpdateLemmas
import Proofs.GameTheory.CoordinationEfficiencyExact

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- The social welfare of the all-moderate Nash equilibrium is 7n. -/
theorem allModerate_welfare (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount) :
    socialWelfare (fulcrumCoordinationGame params)
      (fun _ => AgentAction.moderate) = 7 * params.agentCount := by
  unfold socialWelfare fulcrumCoordinationGame
  have hPayoff : ∀ i : Fin params.agentCount,
      fulcrumPayoff params (fun _ => AgentAction.moderate) i = 7 := by
    intro i
    simpa [allModerate] using allModerate_payoff_eq_seven params hBudget i
  simp_rw [hPayoff]
  rw [sum_const_real]

/-- No strategy profile under tight budget achieves welfare > 9n.
    (9 is the maximum per-agent quality for any action.) -/
theorem welfare_upper_bound (params : BudgetParams) :
    ∀ σ : StrategyProfile (fulcrumCoordinationGame params),
    socialWelfare (fulcrumCoordinationGame params) σ ≤ 9 * params.agentCount := by
  intro σ
  unfold socialWelfare fulcrumCoordinationGame
  calc
    ∑ i : Fin params.agentCount, fulcrumPayoff params (fun j => σ j) i
      ≤ ∑ i : Fin params.agentCount, (9 : ℝ) := by
          refine Finset.sum_le_sum ?_
          intro i hi
          have hn_pos : (0 : ℝ) < params.agentCount := by
            exact_mod_cast params.hPositive
          have hPenaltyNonneg :
              0 ≤ if actionViolates (σ i) then (violationPenalty : ℝ) else 0 := by
            split_ifs <;> norm_num [violationPenalty]
          have hOverflowNonneg :
              0 ≤ if (totalTokens params.agentCount (fun j => σ j) : ℝ) > (params.totalBudget : ℝ)
                then ((totalTokens params.agentCount (fun j => σ j) : ℝ) - (params.totalBudget : ℝ)) /
                  (params.agentCount : ℝ)
                else 0 := by
            by_cases h : ((totalTokens params.agentCount (fun j => σ j) : ℝ) > (params.totalBudget : ℝ))
            · rw [if_pos h]
              exact div_nonneg (sub_nonneg.mpr (le_of_lt h)) (le_of_lt hn_pos)
            · rw [if_neg h]
          have hQualityLe : (actionQuality (σ i) : ℝ) ≤ 9 := by
            cases hσ : σ i <;> norm_num [actionQuality]
          unfold fulcrumPayoff
          nlinarith
    _ = 9 * params.agentCount := by
          rw [sum_const_real]

/-- Under tight budget B=25n, no budget-feasible compliant profile achieves
    welfare exceeding the all-moderate profile. -/
theorem constrained_welfare_optimal (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ∀ σ : StrategyProfile (fulcrumCoordinationGame params),
    withinBudget params (fun j => σ j) →
    socialWelfare (fulcrumCoordinationGame params) σ ≤ 7 * params.agentCount := by
  intro σ hFeasible
  unfold socialWelfare fulcrumCoordinationGame
  have hNoOverflow :
      ¬ ((totalTokens params.agentCount (fun j => σ j) : ℝ) > (params.totalBudget : ℝ)) := by
    exact_mod_cast not_lt.mpr hFeasible
  have hCostBoundNat :
      totalTokens params.agentCount (fun j => σ j) ≤ 25 * params.agentCount := by
    rw [← hBudget]
    exact hFeasible
  calc
    ∑ i : Fin params.agentCount, fulcrumPayoff params (fun j => σ j) i
      ≤ ∑ i : Fin params.agentCount,
          (7 + (4 / 15 : ℝ) * ((actionTokenCost (σ i) : ℝ) - 25)) := by
          refine Finset.sum_le_sum ?_
          intro i hi
          have hAction : ∀ a : AgentAction,
              (actionQuality a : ℝ) -
                  (if actionViolates a then (violationPenalty : ℝ) else 0) ≤
                7 + (4 / 15 : ℝ) * ((actionTokenCost a : ℝ) - 25) := by
            intro a
            cases a
            · have h : (3 : ℝ) ≤ 7 + (4 / 15 : ℝ) * (10 - 25) := by
                norm_num
              simpa [actionQuality, actionViolates, actionTokenCost] using h
            · have h : (7 : ℝ) ≤ 7 + (4 / 15 : ℝ) * (25 - 25) := by
                norm_num
                exact le_rfl
              simpa [actionQuality, actionViolates, actionTokenCost] using h
            · have h : (9 : ℝ) ≤ 7 + (4 / 15 : ℝ) * (50 - 25) := by
                norm_num
              simpa [actionQuality, actionViolates, actionTokenCost] using h
            · have h : (8 : ℝ) ≤ 7 + (4 / 15 : ℝ) * (40 - 25) + 20 := by
                norm_num
                have h8 : (8 : ℝ) ≤ 20 := by norm_num
                have hAdd : (20 : ℝ) ≤ 7 + 4 + 20 := by
                  have h0 : (0 : ℝ) ≤ 7 + 4 := by positivity
                  have hAddRaw : (20 : ℝ) + 0 ≤ 20 + (7 + 4) :=
                    add_le_add_right h0 20
                  simpa [add_assoc, add_left_comm, add_comm] using hAddRaw
                exact le_trans h8 hAdd
              simpa [actionQuality, actionViolates, actionTokenCost, violationPenalty,
                sub_eq_add_neg, add_assoc, add_left_comm, add_comm] using h
          simp [fulcrumPayoff, hNoOverflow]
          have := hAction (σ i)
          nlinarith
    _ = 7 * params.agentCount +
          (4 / 15 : ℝ) *
            ((∑ i : Fin params.agentCount, (actionTokenCost (σ i) : ℝ)) -
              25 * params.agentCount) := by
          rw [Finset.sum_add_distrib]
          rw [sum_const_real]
          rw [← Finset.mul_sum]
          congr 1
          rw [Finset.sum_sub_distrib]
          rw [sum_const_real]
    _ ≤ 7 * params.agentCount := by
          have hTotal :
              (∑ i : Fin params.agentCount, (actionTokenCost (σ i) : ℝ)) ≤
                25 * params.agentCount := by
            unfold totalTokens at hCostBoundNat
            exact_mod_cast hCostBoundNat
          nlinarith

/-- Noncanonical Real-valued compatibility/provenance theorem. Under tight
    budget, the Price of Anarchy is 1 against the constrained welfare optimum
    among budget-feasible profiles. -/
theorem constrained_poa_exact_real_compat (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ConstrainedPriceOfAnarchyBounded
      (fulcrumCoordinationGame params)
      (fun σ => withinBudget params (fun j => σ j))
      1 := by
  unfold ConstrainedPriceOfAnarchyBounded
  intro σ_eq hNash σ_opt hOptFeasible
  have hUpper := constrained_welfare_optimal params hBudget hSmall σ_opt hOptFeasible
  have hEqAllModerate := nash_eq_allModerate params hBudget hSmall σ_eq hNash
  have hEqProfile : (fun j => σ_eq j) = fun _ => AgentAction.moderate := funext hEqAllModerate
  have hEqWelfare :
      socialWelfare (fulcrumCoordinationGame params) σ_eq = 7 * params.agentCount := by
    unfold socialWelfare fulcrumCoordinationGame
    simp_rw [show ∀ j : Fin params.agentCount,
      fulcrumPayoff params (fun k => σ_eq k) j =
        fulcrumPayoff params (fun _ => AgentAction.moderate) j
      from fun j => by rw [hEqProfile]]
    have := allModerate_welfare params hBudget
    unfold socialWelfare fulcrumCoordinationGame at this
    simpa [allModerate] using this
  rw [hEqWelfare]
  nlinarith

/-- Price of Anarchy bound: for the Fulcrum game under tight budget,
    PoA ≤ 9/7. The worst equilibrium (all-moderate) achieves welfare 7n,
    while optimal welfare is at most 9n.

    9/7 ≈ 1.286, meaning at most 28.6% coordination loss.
    This is a mild bound, indicating the governance mechanism
    effectively aligns individual incentives with group welfare.

    The proof uses Nash equilibrium uniqueness: under tight budget (25n) with
    n ≤ 12, all-moderate is the only Nash equilibrium. This follows from:

    1. **Noncompliant eliminated**: Strictly dominated by moderate
       (noncompliant_strictly_dominated).

    2. **No overflow in Nash eq**: If totalTokens > 25n, some agent plays
       aggressive (pigeonhole on costs). That agent's moderate deviation saves
       25/n > 2 overflow per agent (since 25 > 2·12), exceeding the quality
       loss of 2. Combined with conservative agents' Nash conditions (overflow
       difference 15/n ≥ 4 forces n ≤ 3) and integer divisibility of costs
       (all multiples of 5), every overflow scenario leads to contradiction.

    3. **All moderate without overflow**: Conservative agents get payoff 3 but
       moderate deviation yields 7 with no overflow increase (agent's cost
       changes from 10 to 25, and without aggressive agents the total stays
       ≤ 25n). Aggressive agents under no overflow require conservative agents
       by pigeonhole (cost 50 forces others' costs below average), who then
       deviate to moderate. -/
theorem fulcrum_poa_bounded (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    PriceOfAnarchyBounded (fulcrumCoordinationGame params) (9 / 7) := by
  unfold PriceOfAnarchyBounded
  intro σ_eq hNash σ_opt
  -- Upper bound on any profile's welfare
  have h_upper := welfare_upper_bound params σ_opt
  -- Every Nash eq is all-moderate under these constraints (see docstring for proof sketch)
  suffices h_mod : ∀ i, σ_eq i = AgentAction.moderate by
    -- Derive welfare = 7n from all-moderate
    have h_eq : (fun j => σ_eq j) = fun _ => AgentAction.moderate := funext h_mod
    have h_welfare : socialWelfare (fulcrumCoordinationGame params) σ_eq =
        7 * params.agentCount := by
      unfold socialWelfare fulcrumCoordinationGame
      simp_rw [show ∀ j : Fin params.agentCount,
        fulcrumPayoff params (fun k => σ_eq k) j =
          fulcrumPayoff params (fun _ => AgentAction.moderate) j
        from fun j => by rw [h_eq]]
      have := allModerate_welfare params hBudget
      unfold socialWelfare fulcrumCoordinationGame at this
      simpa [allModerate] using this
    -- Combine: welfare(σ_opt) ≤ 9n ≤ (9/7) · 7n = (9/7) · welfare(σ_eq)
    rw [h_welfare]
    have : (0 : ℝ) ≤ (params.agentCount : ℝ) := Nat.cast_nonneg _
    nlinarith
  exact nash_eq_allModerate params hBudget hSmall σ_eq hNash

end Fulcrum.GameTheory
