/-
  Import verification: confirms that key Mathlib4 modules needed
  for game theory proofs are accessible from our proof package.

  This file exists solely to verify dependency wiring.
  It will be converted to a proper module once confirmed.

  Required for Nash equilibrium proofs:
  - Real number arithmetic (ℝ, inequalities, linear arithmetic)
  - Finite types and Finset (finite games, strategy enumeration)
  - Probability (PMF for mixed strategies)
  - Set theory (already verified in BasicInvariants)
  - Convexity (for mixed strategy best-response sets)
-/

import Mathlib.Data.Real.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Probability.ProbabilityMassFunction.Basic
import Mathlib.Topology.Order

set_option autoImplicit false

-- Verify ℝ arithmetic works
#check (7 : ℝ) + (3 : ℝ)
-- ℝ supports ordered arithmetic (verified by the examples below)

-- Verify Fintype/Finset for finite games
#check @Fintype
#check @Finset.sum
#check @Finset.univ

-- Verify PMF for mixed strategies
#check @PMF
#check @PMF.toMeasure

-- Verify we can define basic game-theoretic structures
section GameStructures

variable (n : ℕ) (Action : Type) [Fintype Action] [DecidableEq Action]

-- A strategy profile: each of n players picks an action
def StrategyProfile := Fin n → Action

-- A payoff function: given a strategy profile, returns each player's payoff
def PayoffFunction := (Fin n → Action) → Fin n → ℝ

-- A mixed strategy: probability distribution over actions
def MixedStrategy := PMF Action

end GameStructures

-- Verify linear arithmetic over ℝ
example : (7 : ℝ) > (3 : ℝ) := by norm_num
example : (1 : ℝ) / 2 + 1 / 2 = 1 := by norm_num

-- Verify Finset.sum works with ℝ
example : Finset.sum (Finset.range 3) (fun i => (i : ℝ)) = 3 := by
  simp [Finset.sum_range_succ]; norm_num
