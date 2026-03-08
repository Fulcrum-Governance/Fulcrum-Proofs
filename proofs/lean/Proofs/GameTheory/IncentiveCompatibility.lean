/-
  Incentive Properties for Fulcrum's Proportional Allocation

  The current utility model is `allocationUtility trueNeed allocation = -|allocation - trueNeed|`.
  Under that utility, budget sufficiency does imply that truthful reporting gives an agent at
  least their requested amount, but it does NOT imply DSIC. In oversupplied settings, an agent
  can strictly improve utility by under-reporting to move their allocation closer to their true need.
-/

import Proofs.GameTheory.Definitions
import Mathlib.Algebra.BigOperators.Fin
import Mathlib.Data.Real.Basic

set_option autoImplicit false

namespace Fulcrum.GameTheory

-- ═══════════════════════════════════════════════════════════
-- Proportional allocation mechanism
-- ═══════════════════════════════════════════════════════════

/-- An agent's budget request (their reported need). -/
structure BudgetRequest where
  amount : ℝ
  hPositive : amount > 0

/-- Proportional allocation: each agent receives a share of the total
    budget proportional to their reported need.
    allocation_i = (report_i / total_reports) * budget -/
noncomputable def proportionalAllocation
    {n : Nat} (budget : ℝ) (reports : Fin n → BudgetRequest) (i : Fin n) : ℝ :=
  let totalReported := Finset.sum Finset.univ (fun j => (reports j).amount)
  if totalReported > 0
  then budget * (reports i).amount / totalReported
  else 0

/-- Agent utility: closer to their true need is better.
    utility_i = -|allocation_i - true_need_i|
    (minimizing deviation from desired allocation) -/
noncomputable def allocationUtility
    (trueNeed : ℝ) (allocation : ℝ) : ℝ :=
  -(|allocation - trueNeed|)

-- ═══════════════════════════════════════════════════════════
-- Budget sufficiency and a concrete non-DSIC counterexample
-- ═══════════════════════════════════════════════════════════

/-- Budget sufficiency: the total budget is at least the sum of all
    agents' true needs. Under this condition, truthful reporting
    gives each agent at least their full need. -/
def BudgetSufficient {n : Nat} (budget : ℝ)
    (trueNeeds : Fin n → BudgetRequest) : Prop :=
  budget ≥ Finset.sum Finset.univ (fun i => (trueNeeds i).amount)

/-- Under budget sufficiency, truthful reporting gives each agent
    at least their full requested amount. -/
theorem truthful_allocation_sufficient
    {n : Nat} (budget : ℝ) (trueNeeds : Fin n → BudgetRequest)
    (hSuff : BudgetSufficient budget trueNeeds)
    (_hBudgetPos : budget > 0) (_hn : n > 0) (i : Fin n) :
    proportionalAllocation budget trueNeeds i ≥ (trueNeeds i).amount := by
  unfold proportionalAllocation
  let totalReported := Finset.sum Finset.univ (fun j => (trueNeeds j).amount)
  have hNeedLe : (trueNeeds i).amount ≤ totalReported := by
    dsimp [totalReported]
    exact Finset.single_le_sum
      (fun j _ => le_of_lt (trueNeeds j).hPositive)
      (Finset.mem_univ i)
  have hTotalPos : 0 < totalReported := lt_of_lt_of_le (trueNeeds i).hPositive hNeedLe
  have hTotalLeBudget : totalReported ≤ budget := by
    simpa [BudgetSufficient, totalReported] using hSuff
  rw [if_pos hTotalPos]
  change (trueNeeds i).amount ≤ budget * (trueNeeds i).amount / totalReported
  rw [le_div_iff₀ hTotalPos]
  nlinarith [hTotalLeBudget, (trueNeeds i).hPositive]

/-- Under the current `allocationUtility`, proportional allocation is not DSIC:
    with two agents who both truly need 5 and budget 20, truthful reporting gives
    allocation 10, while under-reporting to 5/3 gives exact allocation 5 and higher utility. -/
theorem proportional_allocation_counterexample_under_sufficiency :
    let trueNeeds : Fin 2 → BudgetRequest := fun _ => ⟨5, by norm_num⟩
    let falseReport : BudgetRequest := ⟨(5 : ℝ) / 3, by norm_num⟩
    BudgetSufficient 20 trueNeeds ∧
      allocationUtility (trueNeeds 0).amount (proportionalAllocation 20 trueNeeds 0) <
        allocationUtility (trueNeeds 0).amount
          (proportionalAllocation 20 (Function.update trueNeeds 0 falseReport) 0) := by
  dsimp
  constructor
  · norm_num [BudgetSufficient]
  · have hTruth : |(20 : ℝ) * 5 / (2 * 5) - 5| = 5 := by
      norm_num
    have hMisreportAlloc :
        (if (0 : ℝ) < (5 : ℝ) / 3 + 5 then 20 * ((5 : ℝ) / 3) / (((5 : ℝ) / 3) + 5) else 0) = 5 := by
      norm_num
      rfl
    have hFalse :
        |((if (0 : ℝ) < (5 : ℝ) / 3 + 5 then 20 * ((5 : ℝ) / 3) / (((5 : ℝ) / 3) + 5) else 0) - 5)| = 0 := by
      rw [hMisreportAlloc]
      norm_num
    simp [allocationUtility, proportionalAllocation, Fin.sum_univ_two]
    rw [hFalse, hTruth]
    norm_num

/-- Formal negation of DSIC for the concrete oversupplied two-agent instance above. -/
theorem proportional_allocation_not_dsic :
    ¬ IsDSIC
      (mechanism := fun (reports : (i : Fin 2) → BudgetRequest) =>
        fun i => proportionalAllocation 20 reports i)
      (utility := fun i trueNeed_i outcome =>
        allocationUtility trueNeed_i.amount (outcome i)) := by
  intro hDSIC
  let trueNeeds : Fin 2 → BudgetRequest := fun _ => ⟨5, by norm_num⟩
  let falseReport : BudgetRequest := ⟨(5 : ℝ) / 3, by norm_num⟩
  have h := hDSIC 0 trueNeeds falseReport
  simp [trueNeeds, falseReport, allocationUtility, proportionalAllocation, Fin.sum_univ_two] at h
  have hTruth : |(20 : ℝ) * 5 / (2 * 5) - 5| = 5 := by norm_num
  have hMisreportAlloc :
      (if (0 : ℝ) < (5 : ℝ) / 3 + 5 then 20 * ((5 : ℝ) / 3) / (((5 : ℝ) / 3) + 5) else 0) = 5 := by
    norm_num
    rfl
  have hFalse :
      |((if (0 : ℝ) < (5 : ℝ) / 3 + 5 then 20 * ((5 : ℝ) / 3) / (((5 : ℝ) / 3) + 5) else 0) - 5)| = 0 := by
    rw [hMisreportAlloc]
    norm_num
  rw [hTruth, hFalse] at h
  norm_num at h

/-- Fulcrum-style corollary: under the current utility model, sufficient budget does
    not make truthful need-reporting a dominant strategy. -/
theorem fulcrum_not_ic_under_sufficiency :
    ∃ (i : Fin 2) (trueNeeds : Fin 2 → BudgetRequest) (falseReport : BudgetRequest),
      BudgetSufficient 20 trueNeeds ∧
      allocationUtility (trueNeeds i).amount (proportionalAllocation 20 trueNeeds i) <
        allocationUtility (trueNeeds i).amount
          (proportionalAllocation 20 (Function.update trueNeeds i falseReport) i) := by
  refine ⟨0, fun _ => ⟨5, by norm_num⟩, ⟨(5 : ℝ) / 3, by norm_num⟩, ?_⟩
  constructor
  · norm_num [BudgetSufficient]
  · have hTruth : |(20 : ℝ) * 5 / (2 * 5) - 5| = 5 := by
      norm_num
    have hMisreportAlloc :
        (if (0 : ℝ) < (5 : ℝ) / 3 + 5 then 20 * ((5 : ℝ) / 3) / (((5 : ℝ) / 3) + 5) else 0) = 5 := by
      norm_num
      rfl
    have hFalse :
        |((if (0 : ℝ) < (5 : ℝ) / 3 + 5 then 20 * ((5 : ℝ) / 3) / (((5 : ℝ) / 3) + 5) else 0) - 5)| = 0 := by
      rw [hMisreportAlloc]
      norm_num
    simp [allocationUtility, proportionalAllocation, Fin.sum_univ_two]
    rw [hFalse, hTruth]
    norm_num

end Fulcrum.GameTheory
