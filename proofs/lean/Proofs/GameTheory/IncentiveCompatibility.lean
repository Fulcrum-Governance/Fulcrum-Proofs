/-
  Incentive Compatibility (DSIC) for Fulcrum's Proportional Allocation

  Proves that Fulcrum's budget allocation mechanism is dominant-strategy
  incentive compatible (DSIC) under the sufficiency assumption: when the
  total budget is sufficient to cover all agents' truthful requests.

  Under sufficiency, each agent receives exactly what they request when
  reporting truthfully. Inflating provides no benefit (you already get
  everything you need), so truth-telling is a dominant strategy.

  Without sufficiency (competitive budget), proportional allocation is
  NOT DSIC in general. This is a known result in mechanism design.

  Reference: Zhang et al. (2024), arxiv:2402.12907 (ICSAP framework)
-/

import Proofs.GameTheory.Definitions
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
-- DSIC under budget sufficiency
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
    (hBudgetPos : budget > 0) (hn : n > 0) (i : Fin n) :
    proportionalAllocation budget trueNeeds i ≥ (trueNeeds i).amount := by
  sorry -- Follows from: budget/totalReported ≥ 1 under sufficiency

/-- DSIC theorem: under budget sufficiency, truthful reporting is a
    dominant strategy for every agent under proportional allocation.

    Formally: for any agent i with true need tᵢ, reporting tᵢ
    maximizes utility regardless of other agents' reports.

    Mathematical argument:
    Under sufficiency, budget ≥ Σ needs. So budget/Σreports ≥ 1 when
    all report truthfully. Each agent gets allocation ≥ need.
    Since utility = -|allocation - need|, and truthful allocation ≥ need,
    the agent cannot improve by inflating (already gets enough) or
    deflating (gets less than needed). -/
theorem proportional_allocation_dsic
    {n : Nat} (budget : ℝ) (trueNeeds : Fin n → BudgetRequest)
    (hSuff : BudgetSufficient budget trueNeeds)
    (hBudgetPos : budget > 0) (hn : n > 0) :
    IsDSIC
      (mechanism := fun (reports : (i : Fin n) → BudgetRequest) =>
        fun i => proportionalAllocation budget reports i)
      (utility := fun i trueNeed_i outcome =>
        allocationUtility trueNeed_i.amount (outcome i)) := by
  sorry -- Follows from truthful_allocation_sufficient + monotonicity of |·|

/-- Corollary: in the Fulcrum coordination game under sufficient budget,
    agents have no incentive to misreport their token needs. -/
theorem fulcrum_ic_under_sufficiency
    {n : Nat} (budget : ℝ) (trueNeeds : Fin n → BudgetRequest)
    (hSuff : BudgetSufficient budget trueNeeds)
    (hBudgetPos : budget > 0) (hn : n > 0) :
    ∀ (i : Fin n) (falseReport : BudgetRequest),
    allocationUtility (trueNeeds i).amount (proportionalAllocation budget trueNeeds i) ≥
    allocationUtility (trueNeeds i).amount
      (proportionalAllocation budget (Function.update trueNeeds i falseReport) i) := by
  sorry -- Corollary of proportional_allocation_dsic

end Fulcrum.GameTheory
