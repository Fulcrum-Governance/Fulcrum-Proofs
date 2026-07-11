/-
  Governed-Execution Kernel (published kernel-supplement module)

  Ported from the released D4 supplement `d4-kernel-supplement.zip`
  (Zenodo record DOI 10.5281/zenodo.19900714, published 2026-04-30),
  where this module backs the paper's coupled pre-execution results and
  Theorem 4.3 (risk-calibrated admissibility). Port deltas versus the
  published bytes: this provenance header and the import paths
  (`TrustTermination`/`BasicInvariants` → `Proofs.*`); declarations are
  verbatim.
-/

import Mathlib.Tactic
import Proofs.TrustTermination
import Proofs.BasicInvariants

namespace Fulcrum

deriving instance Repr for TrustState
deriving instance Repr for AgentBudget

/-- Risk tiers for governed spend-bearing actions. -/
inductive ActionRiskTier where
  | standard
  | highRisk
  deriving DecidableEq, Repr

/-- Combined governance state used by the governed-execution kernel extension. -/
structure GovernedKernelState where
  trustState : TrustState
  budgetState : AgentBudget
  deriving Repr

/-- A governed action carries spend delta and policy risk tier. -/
structure GovernedAction where
  delta : Nat
  riskTier : ActionRiskTier
  deriving Repr

/-- Outcomes of a governed pre-execution decision. -/
inductive GovernedActionResult where
  | blockedByCircuit
  | blockedByPolicy
  | blockedByBudget
  | executed (next : GovernedKernelState)
  deriving Repr

/-- Tiered trust requirements used for admissibility decisions. -/
structure RiskPolicy where
  standardNum : Nat
  standardDen : Nat
  highRiskNum : Nat
  highRiskDen : Nat
  h_standard_pos : 0 < standardNum
  h_standard_den_pos : 0 < standardDen
  h_standard_lt : standardNum < standardDen
  h_high_pos : 0 < highRiskNum
  h_high_den_pos : 0 < highRiskDen
  h_high_lt : highRiskNum < highRiskDen
  h_standard_lt_high : standardNum * highRiskDen < highRiskNum * standardDen

/-- Forget the risk tier and keep the spend-bearing delta. -/
def toFinancialAction (a : GovernedAction) : FinancialAction :=
  { delta := a.delta }

/-- Action-tier trust admissibility. High-risk actions require the
    stricter threshold encoded in the policy. -/
def trustAdmissible (policy : RiskPolicy) (t : TrustState)
    (tier : ActionRiskTier) : Prop :=
  match tier with
  | .standard =>
      ¬ trustBelowThreshold t.α t.β policy.standardNum policy.standardDen
  | .highRisk =>
      ¬ trustBelowThreshold t.α t.β policy.highRiskNum policy.highRiskDen

instance (policy : RiskPolicy) (t : TrustState) (tier : ActionRiskTier) :
    Decidable (trustAdmissible policy t tier) := by
  cases tier <;>
    unfold trustAdmissible trustBelowThreshold trustNum trustDen <;>
    infer_instance

/-- Combined pre-execution governance transition:
    1. reject immediately if the circuit is open;
    2. reject if the action's risk tier does not meet the required trust;
    3. otherwise apply the guarded budget transition. -/
def governedExecute (policy : RiskPolicy)
    (s : GovernedKernelState)
    (a : GovernedAction) : GovernedActionResult :=
  if _hOpen : s.trustState.circuitState = CircuitBreakerState.open then
    .blockedByCircuit
  else if _hTrust : trustAdmissible policy s.trustState a.riskTier then
    match applyAction s.budgetState (toFinancialAction a) with
    | some newBudget =>
        .executed { trustState := s.trustState, budgetState := newBudget }
    | none =>
        .blockedByBudget
  else
    .blockedByPolicy

/-- The trust gate dominates the spend path: once the circuit is open,
    the governed action never reaches the budget mutation step. -/
theorem open_circuit_blocks_before_budget
    (policy : RiskPolicy)
    (s : GovernedKernelState)
    (a : GovernedAction)
    (hOpen : s.trustState.circuitState = CircuitBreakerState.open) :
    governedExecute policy s a = GovernedActionResult.blockedByCircuit := by
  unfold governedExecute
  simp [hOpen]

/-- Any successful governed execution preserves the budget invariant. -/
theorem governed_execution_preserves_budget
    (policy : RiskPolicy)
    (s : GovernedKernelState)
    (a : GovernedAction)
    (next : GovernedKernelState)
    (hExec : governedExecute policy s a = GovernedActionResult.executed next) :
    next.budgetState.currentSpent <= next.budgetState.aggregateLimit := by
  by_cases hOpen : s.trustState.circuitState = CircuitBreakerState.open
  · have hBlocked := open_circuit_blocks_before_budget policy s a hOpen
    rw [hBlocked] at hExec
    cases hExec
  · by_cases hTrust : trustAdmissible policy s.trustState a.riskTier
    · simp [governedExecute, hOpen, hTrust] at hExec
      cases hApply : applyAction s.budgetState (toFinancialAction a) with
      | none =>
          simp [hApply] at hExec
      | some newBudget =>
          simp [hApply] at hExec
          rcases hExec with rfl
          exact budget_safety_guarantee
            s.budgetState
            (toFinancialAction a)
            newBudget
            hApply
    · simp [governedExecute, hOpen, hTrust] at hExec

/-- Pack the two governed-execution kernel halves into one theorem family:
    open circuits block pre-execution, and successful execution preserves
    spend safety. -/
theorem governed_kernel_pre_execution_safety
    (policy : RiskPolicy)
    (s : GovernedKernelState)
    (a : GovernedAction) :
    (s.trustState.circuitState = CircuitBreakerState.open →
      governedExecute policy s a = GovernedActionResult.blockedByCircuit) ∧
    (∀ next,
      governedExecute policy s a = GovernedActionResult.executed next →
        next.budgetState.currentSpent <= next.budgetState.aggregateLimit) := by
  constructor
  · intro hOpen
    exact open_circuit_blocks_before_budget policy s a hOpen
  · intro next hExec
    exact governed_execution_preserves_budget policy s a next hExec

/-- A high-risk execution can only succeed when the stronger threshold
    is satisfied in the source trust state. -/
theorem high_risk_execution_requires_stronger_trust
    (policy : RiskPolicy)
    (s : GovernedKernelState)
    (δ : Nat)
    (next : GovernedKernelState)
    (hExec : governedExecute policy s
      { delta := δ, riskTier := ActionRiskTier.highRisk } =
        GovernedActionResult.executed next) :
    ¬ trustBelowThreshold
      s.trustState.α
      s.trustState.β
      policy.highRiskNum
      policy.highRiskDen := by
  by_cases hOpen : s.trustState.circuitState = CircuitBreakerState.open
  · have hBlocked := open_circuit_blocks_before_budget
      policy s { delta := δ, riskTier := ActionRiskTier.highRisk } hOpen
    rw [hBlocked] at hExec
    cases hExec
  · by_cases hTrust : trustAdmissible policy s.trustState ActionRiskTier.highRisk
    · simpa [trustAdmissible] using hTrust
    · simp [governedExecute, hOpen, hTrust] at hExec

/-- Risk-calibrated admissibility: if a high-risk action executes, then the
    stronger trust threshold held and the spend bound is still preserved. -/
theorem high_risk_execution_kernel_guarantee
    (policy : RiskPolicy)
    (s : GovernedKernelState)
    (δ : Nat)
    (next : GovernedKernelState)
    (hExec : governedExecute policy s
      { delta := δ, riskTier := ActionRiskTier.highRisk } =
        GovernedActionResult.executed next) :
    (¬ trustBelowThreshold
      s.trustState.α
      s.trustState.β
      policy.highRiskNum
      policy.highRiskDen) ∧
    next.budgetState.currentSpent <= next.budgetState.aggregateLimit := by
  constructor
  · exact high_risk_execution_requires_stronger_trust policy s δ next hExec
  · exact governed_execution_preserves_budget
      policy s { delta := δ, riskTier := ActionRiskTier.highRisk } next hExec

end Fulcrum
