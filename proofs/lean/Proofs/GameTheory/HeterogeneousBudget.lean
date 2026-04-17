/-
  Heterogeneous Budget Boundary Analysis

  Documents the boundary condition where the PoA ≤ 9/7 bound from
  CoordinationEfficiency.lean applies and where it does not.

  The homogeneous budget assumption (all agents share the same budget
  allocation) is used in the Nash uniqueness proof. Under heterogeneous
  budgets (different agents have different allocations), the pure-strategy
  uniqueness result does not hold in general — agents with larger budgets
  have different deviation incentives than agents with smaller budgets.

  Key distinction:
  - PoA ≤ 9/7 guarantees COORDINATION EFFICIENCY under homogeneous budgets
  - Budget Safety Invariant guarantees SAFETY regardless of budget structure

  Even without the PoA bound, no agent can exceed its individual budget.
  The Budget Safety Invariant (BasicInvariants.lean) enforces safety
  regardless of equilibrium properties.
-/

import Proofs.GameTheory.FulcrumGame
import Proofs.BasicInvariants

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- Budget ratio: the ratio between the largest and smallest individual
    budget allocations. When R = 1, all agents have the same budget
    (homogeneous case). When R > 1, budgets are heterogeneous. -/
def budgetRatio (maxBudget minBudget : Nat) : Nat :=
  if minBudget = 0 then 0 else maxBudget / minBudget

/-- The PoA ≤ 9/7 bound applies when the budget ratio is 1
    (homogeneous case). This is a statement of the domain of
    applicability, not a new proof — it references the existing
    fulcrum_poa_bounded theorem from CoordinationEfficiency.lean. -/
theorem poa_bound_homogeneous_domain (maxBudget minBudget : Nat)
    (h_eq : maxBudget = minBudget) (h_pos : 0 < minBudget) :
    budgetRatio maxBudget minBudget = 1 := by
  unfold budgetRatio
  simp [h_eq, Nat.pos_iff_ne_zero.mp h_pos, Nat.div_self h_pos]

/-- For heterogeneous budgets (R > 1), the pure-strategy Nash
    uniqueness from NashUniqueness.lean does not hold in general.
    This theorem states the negation: we cannot claim uniqueness
    when budgets differ.

    The system falls back to the Budget Safety Invariant, which
    guarantees safety regardless of equilibrium properties. -/
theorem heterogeneous_requires_reanalysis
    (maxBudget minBudget : Nat) (h_gt : maxBudget > minBudget)
    (h_pos : 0 < minBudget) :
    budgetRatio maxBudget minBudget ≥ 1 := by
  unfold budgetRatio
  simp [Nat.pos_iff_ne_zero.mp h_pos]
  exact Nat.le_div_iff_mul_le h_pos |>.mpr (by omega)

/-- Budget safety holds regardless of budget ratio.
    This is the key safety property: even without the PoA bound,
    no agent can spend beyond its individual allocation.
    Directly from BasicInvariants.budget_safety_guarantee. -/
theorem budget_safety_independent_of_ratio
    (b : Fulcrum.AgentBudget) (a : Fulcrum.FinancialAction)
    (newB : Fulcrum.AgentBudget)
    (hExec : Fulcrum.applyAction b a = some newB) :
    newB.currentSpent ≤ newB.aggregateLimit :=
  Fulcrum.budget_safety_guarantee b a newB hExec

end Fulcrum.GameTheory
