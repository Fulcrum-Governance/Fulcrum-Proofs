/-
  Fulcrum Coordination Game Model

  Maps Fulcrum's multi-agent governance mechanism into the game theory
  framework from Definitions.lean. The model captures:
  - Agents as players choosing from finite action sets
  - Shared budget as a commons (token competition)
  - Policy violation penalty as governance enforcement
  - Quality/cost tradeoff as the payoff structure

  Real-world mapping:
  - AgentAction → protobuf ActionType enum
  - actionTokenCost → Cost Service token accounting
  - actionViolates → Immune System incident detection
  - violationPenalty → BLOCK/TERMINATE enforcement
  - withinBudget → budget_safety_guarantee from BasicInvariants.lean
-/

import Proofs.GameTheory.Definitions
import Proofs.BasicInvariants

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- Agent actions in the Fulcrum coordination game.
    Maps to real agent choices:
    - conservative: minimal token use, always policy-compliant
    - moderate: balanced quality/cost, compliant
    - aggressive: high token use, risks budget pressure on others
    - noncompliant: violates policy for short-term quality gain -/
inductive AgentAction where
  | conservative  -- 10 tokens, quality 3
  | moderate      -- 25 tokens, quality 7
  | aggressive    -- 50 tokens, quality 9
  | noncompliant  -- 40 tokens, quality 8, triggers violation penalty
  deriving DecidableEq, Repr

instance : Fintype AgentAction where
  elems := {.conservative, .moderate, .aggressive, .noncompliant}
  complete := fun x => by cases x <;> simp

instance : Nonempty AgentAction := ⟨AgentAction.conservative⟩

/-- Token cost per action. Maps to Cost Service token accounting. -/
def actionTokenCost : AgentAction → Nat
  | .conservative  => 10
  | .moderate      => 25
  | .aggressive    => 50
  | .noncompliant  => 40

/-- Quality score per action. Maps to task completion quality metrics. -/
def actionQuality : AgentAction → Nat
  | .conservative  => 3
  | .moderate      => 7
  | .aggressive    => 9
  | .noncompliant  => 8

/-- Policy violation flag. Maps to Immune System incident detection. -/
def actionViolates : AgentAction → Bool
  | .noncompliant  => true
  | _              => false

/-- Violation penalty. Maps to governance enforcement: policy violation
    triggers BLOCK/TERMINATE + future action space restriction.
    Set high enough that noncompliant is strictly dominated. -/
def violationPenalty : Nat := 20

/-- Budget parameters for the coordination game.
    Maps to Cost Service BudgetConfig: totalBudget is the shared
    per-workflow token budget across all agents in a team. -/
structure BudgetParams where
  totalBudget : Nat
  agentCount : Nat
  hPositive : agentCount > 0

/-- Total tokens consumed by a strategy profile. -/
def totalTokens (n : Nat) (profile : Fin n → AgentAction) : Nat :=
  Finset.sum Finset.univ (fun i => actionTokenCost (profile i))

/-- Whether a strategy profile stays within budget.
    Backed by budget_safety_guarantee from BasicInvariants.lean:
    the runtime enforces this constraint via applyAction gating. -/
def withinBudget (params : BudgetParams)
    (profile : Fin params.agentCount → AgentAction) : Prop :=
  totalTokens params.agentCount profile ≤ params.totalBudget

/-- Agent payoff in the Fulcrum coordination game.
    payoff_i = quality_i - violation_penalty_i - budget_overflow_share
    Budget overflow is shared equally (all agents blocked when budget exhausted). -/
noncomputable def fulcrumPayoff (params : BudgetParams)
    (profile : Fin params.agentCount → AgentAction)
    (i : Fin params.agentCount) : ℝ :=
  let quality := (actionQuality (profile i) : ℝ)
  let penalty := if actionViolates (profile i) then (violationPenalty : ℝ) else 0
  let total := (totalTokens params.agentCount profile : ℝ)
  let budgetOverflow := if total > (params.totalBudget : ℝ)
    then (total - (params.totalBudget : ℝ)) / (params.agentCount : ℝ)
    else 0
  quality - penalty - budgetOverflow

/-- The Fulcrum coordination game as a normal-form game. -/
noncomputable def fulcrumCoordinationGame (params : BudgetParams) :
    NormalFormGame params.agentCount where
  Strategy := fun _ => AgentAction
  strategyFintype := fun _ => inferInstance
  strategyNonempty := fun _ => inferInstance
  strategyDecEq := fun _ => inferInstance
  payoff := fun i profile => fulcrumPayoff params (fun j => profile j) i

end Fulcrum.GameTheory
