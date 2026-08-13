/-
  Exact, division-free coordination-game definitions.

  This module is the canonical data surface for the constrained PoA result.
  It deliberately avoids Real-valued payoffs and Finset aggregation.  A signed
  value `pos - neg` is ordered by cross-addition, and every aggregate is built
  by structural recursion over `Fin n` profiles.  The separately imported
  correspondence module proves equivalence with the legacy Real model.
-/

import Proofs.GameTheory.FulcrumGame

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- A signed integer represented exactly as a difference of natural numbers. -/
structure SignedNat where
  pos : Nat
  neg : Nat
deriving DecidableEq, Repr

namespace SignedNat

/-- Zero in the signed-natural representation. -/
def zero : SignedNat := ⟨0, 0⟩

/-- Addition of signed-natural representatives. -/
def add (x y : SignedNat) : SignedNat :=
  ⟨x.pos + y.pos, x.neg + y.neg⟩

/-- Natural scaling of a signed-natural representative. -/
def nsmul (k : Nat) (x : SignedNat) : SignedNat :=
  ⟨k * x.pos, k * x.neg⟩

/-- Exact order on represented differences: `x.pos - x.neg ≤ y.pos - y.neg`. -/
def le (x y : SignedNat) : Prop :=
  x.pos + y.neg ≤ y.pos + x.neg

instance : LE SignedNat := ⟨le⟩

@[simp] theorem zero_pos : zero.pos = 0 := rfl
@[simp] theorem zero_neg : zero.neg = 0 := rfl
@[simp] theorem add_pos (x y : SignedNat) : (add x y).pos = x.pos + y.pos := rfl
@[simp] theorem add_neg (x y : SignedNat) : (add x y).neg = x.neg + y.neg := rfl
@[simp] theorem nsmul_pos (k : Nat) (x : SignedNat) : (nsmul k x).pos = k * x.pos := rfl
@[simp] theorem nsmul_neg (k : Nat) (x : SignedNat) : (nsmul k x).neg = k * x.neg := rfl

end SignedNat

/-- A profile for the exact coordination game. -/
abbrev ExactProfile (n : Nat) := Fin n → AgentAction

/-- The structural roster corresponding to every index in a profile. -/
def exactRoster {n : Nat} (profile : ExactProfile n) : List AgentAction :=
  List.ofFn profile

/-- Structural natural-number aggregation over a finite profile. -/
def structuralSum {α : Type} (f : α → Nat) : {n : Nat} → (Fin n → α) → Nat
  | 0, _ => 0
  | n + 1, profile =>
      f (profile 0) + structuralSum f (fun i : Fin n => profile i.succ)

/-- Structural signed-natural aggregation over a finite profile. -/
def structuralSignedSum : {n : Nat} → (Fin n → SignedNat) → SignedNat
  | 0, _ => SignedNat.zero
  | n + 1, values =>
      SignedNat.add (values 0)
        (structuralSignedSum (fun i : Fin n => values i.succ))

/-- Exact action cost, intentionally case-defined for kernel reduction. -/
def exactActionCost : AgentAction → Nat
  | .conservative => 10
  | .moderate => 25
  | .aggressive => 50
  | .noncompliant => 40

/-- Exact action quality, intentionally case-defined for kernel reduction. -/
def exactActionQuality : AgentAction → Nat
  | .conservative => 3
  | .moderate => 7
  | .aggressive => 9
  | .noncompliant => 8

/-- Exact policy-violation flag. -/
def exactActionViolates : AgentAction → Bool
  | .noncompliant => true
  | _ => false

/-- Exact violation penalty. -/
def exactViolationPenalty : Nat := 20

/-- Per-action exact penalty contribution. -/
def exactActionPenalty (a : AgentAction) : Nat :=
  if exactActionViolates a then exactViolationPenalty else 0

/-- Structural token total of a profile. -/
def exactTotalTokens {n : Nat} (profile : ExactProfile n) : Nat :=
  structuralSum exactActionCost profile

/-- Structural total quality of a profile. -/
def exactTotalQuality {n : Nat} (profile : ExactProfile n) : Nat :=
  structuralSum exactActionQuality profile

/-- Structural total violation penalty of a profile. -/
def exactTotalPenalty {n : Nat} (profile : ExactProfile n) : Nat :=
  structuralSum exactActionPenalty profile

/-- Structural number of agents playing a selected action. -/
def exactActionCount {n : Nat} (a : AgentAction) (profile : ExactProfile n) : Nat :=
  structuralSum (fun b => if b = a then 1 else 0) profile

/-- Exact budget feasibility. -/
def exactWithinBudget (params : BudgetParams)
    (profile : ExactProfile params.agentCount) : Prop :=
  exactTotalTokens profile ≤ params.totalBudget

/-- Exact overflow above the shared budget. -/
def exactOverflow (params : BudgetParams)
    (profile : ExactProfile params.agentCount) : Nat :=
  exactTotalTokens profile - params.totalBudget

/--
The legacy payoff multiplied by the positive common denominator `agentCount`.
Positive and negative parts remain natural-number data.
-/
def exactPayoffNumerator (params : BudgetParams)
    (profile : ExactProfile params.agentCount)
    (i : Fin params.agentCount) : SignedNat :=
  ⟨params.agentCount * exactActionQuality (profile i),
    params.agentCount * exactActionPenalty (profile i) +
      exactOverflow params profile⟩

/-- A unilateral exact-profile update. -/
def exactUpdate {n : Nat} (profile : ExactProfile n) (i : Fin n)
    (action : AgentAction) : ExactProfile n :=
  Function.update profile i action

/-- Pure Nash equilibrium for the exact payoff order. -/
def ExactIsNash (params : BudgetParams)
    (profile : ExactProfile params.agentCount) : Prop :=
  ∀ i action,
    exactPayoffNumerator params (exactUpdate profile i action) i ≤
      exactPayoffNumerator params profile i

/-- The all-moderate exact profile. -/
def exactAllModerate (n : Nat) : ExactProfile n :=
  fun _ => .moderate

/-- Structural sum of all exact payoff numerators. -/
def exactWelfareNumerator (params : BudgetParams)
    (profile : ExactProfile params.agentCount) : SignedNat :=
  structuralSignedSum (fun i => exactPayoffNumerator params profile i)

/-- The exact numerator attained by all-moderate: `(7*n) * n`. -/
def exactAllModerateWelfareNumerator (n : Nat) : SignedNat :=
  ⟨7 * n * n, 0⟩

/-- Every feasible exact profile is welfare-bounded by all-moderate. -/
def ExactWelfareOptimal (params : BudgetParams) : Prop :=
  ∀ profile, exactWithinBudget params profile →
    exactWelfareNumerator params profile ≤
      exactWelfareNumerator params (exactAllModerate params.agentCount)

/-- Relational constrained PoA bound on exact welfare numerators. -/
def ExactConstrainedPoABounded (params : BudgetParams) (bound : Nat) : Prop :=
  ∀ equilibrium, ExactIsNash params equilibrium →
    ∀ optimum, exactWithinBudget params optimum →
      exactWelfareNumerator params optimum ≤
        SignedNat.nsmul bound (exactWelfareNumerator params equilibrium)

/--
The complete founder-protected exact claim: all-moderate Nash existence,
pointwise uniqueness, feasibility, exact `7*n` attainment (encoded over the
common denominator `n`), constrained welfare optimality, and relational PoA
at exactly one.
-/
def ExactFullClaim (params : BudgetParams) : Prop :=
  ExactIsNash params (exactAllModerate params.agentCount) ∧
  (∀ profile, ExactIsNash params profile →
    ∀ i, profile i = exactAllModerate params.agentCount i) ∧
  exactWithinBudget params (exactAllModerate params.agentCount) ∧
  exactWelfareNumerator params (exactAllModerate params.agentCount) =
    exactAllModerateWelfareNumerator params.agentCount ∧
  ExactWelfareOptimal params ∧
  ExactConstrainedPoABounded params 1

end Fulcrum.GameTheory
