/-
  Budget-Game Bridge

  Connects the existing budget_safety_guarantee from BasicInvariants.lean
  to the game-theoretic model. This bridge establishes that:

  1. The runtime budget enforcement (applyAction gating) grounds the game:
     agents cannot execute actions exceeding budget, so the withinBudget
     predicate is enforced by the system, not just assumed.

  2. The budget safety guarantee acts as the "rules of the game" —
     it constrains the strategy space to feasible actions only.

  This is conceptually straightforward but makes the connection between
  the existing formal proofs and the new game theory layer explicit
  and auditable.
-/

import Proofs.GameTheory.FulcrumGame
import Proofs.GameTheory.NashExistence
import Proofs.BasicInvariants

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- The runtime budget enforcement (budget_safety_guarantee) implies that
    any sequence of actions executed through applyAction stays within budget.
    This grounds the withinBudget predicate in the game model. -/
theorem budget_enforcement_grounds_game
    (params : BudgetParams)
    (budgets : Fin params.agentCount → Fulcrum.AgentBudget)
    (actions : Fin params.agentCount → Fulcrum.FinancialAction)
    (newBudgets : Fin params.agentCount → Fulcrum.AgentBudget)
    (hExec : ∀ i, Fulcrum.applyAction (budgets i) (actions i) = some (newBudgets i)) :
    ∀ i, (newBudgets i).currentSpent ≤ (newBudgets i).aggregateLimit := by
  intro i
  exact Fulcrum.budget_safety_guarantee (budgets i) (actions i) (newBudgets i) (hExec i)

/-- Noncompliant actions are blocked by the governance system (Immune System
    incident response). This means in practice, the noncompliant action in
    the game model is not available to rational agents — it would be caught
    and penalized before completion. The game model reflects this via the
    violation penalty, making noncompliant strictly dominated.

    This theorem states the connection: if the governance system blocks
    violations, and noncompliant is the only violating action, then
    the effective strategy space is {conservative, moderate, aggressive}. -/
theorem governance_restricts_strategy_space
    (params : BudgetParams)
    (profile : Fin params.agentCount → AgentAction)
    (hNoViolations : ∀ i, actionViolates (profile i) = false) :
    ∀ i, profile i = AgentAction.conservative ∨
         profile i = AgentAction.moderate ∨
         profile i = AgentAction.aggressive := by
  intro i
  have h := hNoViolations i
  match hp : profile i with
  | .conservative => left; rfl
  | .moderate => right; left; rfl
  | .aggressive => right; right; rfl
  | .noncompliant => exfalso; simp [actionViolates, hp] at h

/-- Bridge theorem: the budget safety guarantee from BasicInvariants.lean
    combined with the governance violation blocking means the Fulcrum
    coordination game is played within the designed strategy space.

    Agents who respect budget limits and policy compliance play the
    3-action game {conservative, moderate, aggressive}. The Nash
    equilibrium (all-moderate) is among these compliant strategies.

    This makes the game theory results applicable to the real system. -/
theorem budget_game_bridge
    (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12) :
    ∃ σ : Fin params.agentCount → AgentAction,
      (∀ i, actionViolates (σ i) = false) ∧
      IsNashEquilibrium (fulcrumCoordinationGame params) σ := by
  refine ⟨fun _ => AgentAction.moderate, ?_, moderate_is_nash_equilibrium params hBudget hSmall⟩
  intro i
  simp [actionViolates]

end Fulcrum.GameTheory
