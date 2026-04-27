/-
  Game Theory Foundations for Fulcrum Coordination Proofs

  Defines finite normal-form games, Nash equilibrium, Pareto optimality,
  social welfare, and Price of Anarchy. These are the core structures
  upon which all subsequent game-theoretic theorems depend.

  All existence proofs using these definitions are `noncomputable` by design:
  Lean proves existence, Python computes equilibria.
-/

import Mathlib.Probability.ProbabilityMassFunction.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- A finite normal-form game with `n` players. Each player has a finite
    strategy set and a real-valued payoff function over strategy profiles. -/
structure NormalFormGame (n : Nat) where
  /-- Strategy type for each player -/
  Strategy : Fin n → Type
  /-- Each strategy type is finite -/
  strategyFintype : ∀ i, Fintype (Strategy i)
  /-- Each strategy type is nonempty -/
  strategyNonempty : ∀ i, Nonempty (Strategy i)
  /-- Each strategy type has decidable equality -/
  strategyDecEq : ∀ i, DecidableEq (Strategy i)
  /-- Payoff function for each player given a strategy profile -/
  payoff : (i : Fin n) → ((j : Fin n) → Strategy j) → ℝ

/-- A strategy profile assigns a strategy to each player. -/
def StrategyProfile {n : Nat} (G : NormalFormGame n) :=
  (i : Fin n) → G.Strategy i

/-- A mixed strategy for player `i` is a probability distribution over
    their pure strategies. -/
noncomputable def MixedStrategy {n : Nat} (G : NormalFormGame n) (i : Fin n) :=
  @PMF (G.Strategy i)

/-- A mixed strategy profile assigns a mixed strategy to each player. -/
noncomputable def MixedStrategyProfile {n : Nat} (G : NormalFormGame n) :=
  (i : Fin n) → MixedStrategy G i

/-- Player `i`'s best response: a strategy that maximizes their payoff
    given other players' strategies are fixed. -/
def IsBestResponse {n : Nat} (G : NormalFormGame n) (i : Fin n)
    (σ : StrategyProfile G) : Prop :=
  ∀ s' : G.Strategy i,
    G.payoff i σ ≥ G.payoff i (Function.update σ i s')

/-- A Nash equilibrium is a strategy profile where every player is
    playing a best response. -/
def IsNashEquilibrium {n : Nat} (G : NormalFormGame n)
    (σ : StrategyProfile G) : Prop :=
  ∀ i : Fin n, IsBestResponse G i σ

/-- A strategy `s` weakly dominates `s'` for player `i`: at least as good
    against all opponent profiles, strictly better against some. -/
def WeaklyDominates {n : Nat} (G : NormalFormGame n) (i : Fin n)
    (s s' : G.Strategy i) : Prop :=
  (∀ σ : StrategyProfile G, σ i = s →
      G.payoff i σ ≥ G.payoff i (Function.update σ i s')) ∧
  (∃ σ : StrategyProfile G, σ i = s ∧
      G.payoff i σ > G.payoff i (Function.update σ i s'))

/-- A strategy profile is Pareto optimal if no player can be made
    better off without making another worse off. -/
def IsParetoOptimal {n : Nat} (G : NormalFormGame n)
    (σ : StrategyProfile G) : Prop :=
  ¬ ∃ σ' : StrategyProfile G,
    (∀ i, G.payoff i σ' ≥ G.payoff i σ) ∧
    (∃ i, G.payoff i σ' > G.payoff i σ)

/-- Social welfare: sum of all players' payoffs. -/
noncomputable def socialWelfare {n : Nat} (G : NormalFormGame n)
    (σ : StrategyProfile G) : ℝ :=
  Finset.sum Finset.univ (fun i => G.payoff i σ)

/-- Price of Anarchy bounded by `bound`: the ratio of optimal social welfare
    to worst-case Nash equilibrium welfare is at most `bound`.
    A lower bound means less coordination loss. -/
def PriceOfAnarchyBounded {n : Nat} (G : NormalFormGame n) (bound : ℝ) : Prop :=
  ∀ σ_eq : StrategyProfile G,
    IsNashEquilibrium G σ_eq →
    ∀ σ_opt : StrategyProfile G,
      socialWelfare G σ_opt ≤ bound * socialWelfare G σ_eq

/-- Constrained Price of Anarchy bounded by `bound`: the ratio of optimal
    feasible welfare to worst-case Nash equilibrium welfare is at most `bound`.
    The feasibility predicate keeps domain-specific constraints, such as a
    token budget, out of the generic game theory definitions. -/
def ConstrainedPriceOfAnarchyBounded {n : Nat} (G : NormalFormGame n)
    (feasible : StrategyProfile G → Prop) (bound : ℝ) : Prop :=
  ∀ σ_eq : StrategyProfile G,
    IsNashEquilibrium G σ_eq →
    ∀ σ_opt : StrategyProfile G,
      feasible σ_opt →
      socialWelfare G σ_opt ≤ bound * socialWelfare G σ_eq

/-- Incentive compatibility: truthful reporting is a dominant strategy.
    For mechanism `M`, agent `i` with type `tᵢ` weakly prefers reporting
    truthfully regardless of other agents' reports. -/
def IsDSIC {n : Nat} {AgentType : Fin n → Type} {Outcome : Type}
    (mechanism : ((i : Fin n) → AgentType i) → Outcome)
    (utility : (i : Fin n) → AgentType i → Outcome → ℝ) : Prop :=
  ∀ (i : Fin n) (types : (j : Fin n) → AgentType j) (t'_i : AgentType i),
    utility i (types i) (mechanism types) ≥
    utility i (types i) (mechanism (Function.update types i t'_i))

end Fulcrum.GameTheory
