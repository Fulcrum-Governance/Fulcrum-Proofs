/-
  Integer-Audit Companion: Constrained Welfare Optimality over ℤ

  A quotient-free, choice-free companion to the ℝ-valued results in
  CoordinationEfficiency.lean. Welfare is scaled by 15 (clearing the 4/15
  budget slope used there) and summed by structural recursion over a
  List — no reals, no Finset (whose Multiset carrier is a quotient), no
  funext — so the axiom cone stays minimal. The achieved profile is
  asserted by probes/check_central_axioms.lean.

  Scope, to be stated wherever these results are cited:
  - These theorems bound scaled welfare against the budget-feasible
    optimum and exhibit the all-moderate roster attaining it — the
    integer, division-free form of "constrained PoA = 1"
    (welfare ratios compare as `welfare15 l ≤ welfare15 allModerate`).
  - They carry NO Nash quantifier. That all-moderate is the unique
    equilibrium is part of the canonical exact theorem at profile [propext].
    The noncanonical Real compatibility theorem
    constrained_poa_exact_real_compat retains the legacy profile
    [propext, Classical.choice, Quot.sound].
  - Unlike the canonical full claim, no `n ≤ 12` hypothesis is needed here: the
    welfare core is universal in the roster size.

  netQuality15 is case-defined for kernel-friendly reduction;
  netQuality15_spec re-derives it from the game's own actionQuality /
  actionViolates / violationPenalty so the numerals cannot drift from
  the model in FulcrumGame.lean.
-/

import Proofs.GameTheory.FulcrumGame

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- Net per-agent quality scaled by 15, case-defined. -/
def netQuality15 : AgentAction → Int
  | .conservative => 15 * 3
  | .moderate => 15 * 7
  | .aggressive => 15 * 9
  | .noncompliant => 15 * 8 - 15 * 20

/-- Token cost as an integer. -/
def actionCostZ (a : AgentAction) : Int :=
  (actionTokenCost a : Int)

/-- `netQuality15` agrees with the game model's own quality/violation data:
    `15·(quality − penalty·[violates])`. Guards against numeral drift. -/
theorem netQuality15_spec (a : AgentAction) :
    netQuality15 a =
      15 * (actionQuality a : Int) -
        (if actionViolates a then 15 * (violationPenalty : Int) else 0) := by
  cases a <;>
    simp [netQuality15, actionQuality, actionViolates, violationPenalty]

/-- Scaled welfare of a roster of actions, by structural recursion. -/
def welfare15 : List AgentAction → Int
  | [] => 0
  | a :: rest => netQuality15 a + welfare15 rest

/-- Total token cost of a roster, by structural recursion. -/
def rosterCost : List AgentAction → Int
  | [] => 0
  | a :: rest => actionCostZ a + rosterCost rest

/-- Per-action linear audit: `netQuality15 a ≤ 105 + 4·(cost a − 25)`.
    Four concrete integer inequalities, one per action. -/
theorem netQuality15_le_linear (a : AgentAction) :
    netQuality15 a ≤ 105 + 4 * (actionCostZ a - 25) := by
  cases a <;>
    simp only [netQuality15, actionCostZ, actionTokenCost] <;>
    omega

/-- Roster-level linear audit: scaled welfare is bounded by
    `105·n + 4·(total cost − 25·n)`. -/
theorem welfare15_le_linear (l : List AgentAction) :
    welfare15 l ≤ 105 * l.length + 4 * (rosterCost l - 25 * l.length) := by
  induction l with
  | nil =>
      simp only [welfare15, rosterCost, List.length_nil]
      omega
  | cons a rest ih =>
      have ha := netQuality15_le_linear a
      simp only [welfare15, rosterCost, List.length_cons]
      omega

/-- Constrained welfare optimality over ℤ: any budget-feasible roster
    (total cost within the 25-per-agent budget) has scaled welfare at
    most `105·n`, i.e. unscaled welfare at most `7·n`. -/
theorem constrained_welfare_optimal_int (l : List AgentAction)
    (hFeasible : rosterCost l ≤ 25 * l.length) :
    welfare15 l ≤ 105 * l.length := by
  have h := welfare15_le_linear l
  omega

/-- The all-moderate roster attains the bound exactly. -/
theorem allModerate_welfare15 (n : Nat) :
    welfare15 (List.replicate n AgentAction.moderate) = 105 * n := by
  induction n with
  | zero =>
      simp only [List.replicate, welfare15]
      omega
  | succ k ih =>
      simp only [List.replicate, welfare15, netQuality15, ih]
      omega

/-- The all-moderate roster is budget-feasible: it spends the budget
    exactly. -/
theorem allModerate_cost_int (n : Nat) :
    rosterCost (List.replicate n AgentAction.moderate) = 25 * n := by
  induction n with
  | zero =>
      simp only [List.replicate, rosterCost]
      omega
  | succ k ih =>
      simp only [List.replicate, rosterCost, actionCostZ, actionTokenCost, ih]
      omega

/-- Integer, division-free form of "constrained PoA = 1": every
    budget-feasible roster is welfare-bounded by the all-moderate roster
    of the same size, which is itself feasible (allModerate_cost_int) and
    attains the optimum (allModerate_welfare15). No Nash quantifier — see
    the module docstring. -/
theorem constrained_poa_exact_int (l : List AgentAction)
    (hFeasible : rosterCost l ≤ 25 * l.length) :
    welfare15 l ≤ welfare15 (List.replicate l.length AgentAction.moderate) := by
  rw [allModerate_welfare15]
  exact constrained_welfare_optimal_int l hFeasible

end Fulcrum.GameTheory
