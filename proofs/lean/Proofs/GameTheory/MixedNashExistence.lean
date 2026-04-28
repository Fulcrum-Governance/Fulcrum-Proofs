/-
  Mixed-Strategy Nash Equilibrium Existence

  Nash's theorem: every finite normal-form game admits at least
  one mixed-strategy Nash equilibrium.

  Closed via math-xmum/Brouwer's `ExistsNashEq`, applied through a
  PMF ↔ stdSimplex bridge. The original axiomatized Kakutani FPT
  has been removed; this proof grounds Nash existence in Brouwer
  on product simplices via Scarf's Lemma (math-xmum dependency).

  Reference: Nash (1951), "Non-cooperative Games", Annals of Mathematics.
-/

import Proofs.GameTheory.Definitions
import Mathlib.Data.Fintype.BigOperators
import Mathlib.Data.Fintype.Pi
import Mathlib.Probability.ProbabilityMassFunction.Basic
import Mathlib.Analysis.Convex.StdSimplex
import Gametheory.Nash

set_option autoImplicit false

open Classical

namespace Fulcrum.GameTheory

attribute [local instance] NormalFormGame.strategyFintype NormalFormGame.strategyDecEq

-- ═══════════════════════════════════════════════════════════
-- Bridges between PMF and stdSimplex
-- ═══════════════════════════════════════════════════════════

/-- Convert a PMF on a finite type to a point in the standard simplex. -/
noncomputable def pmfToSimplex {α : Type*} [Fintype α] (p : PMF α) :
    stdSimplex ℝ α := by
  refine ⟨fun a => (p a).toReal, ?_, ?_⟩
  · intro a
    exact ENNReal.toReal_nonneg
  · have h_ne_top : ∀ a : α, p a ≠ ⊤ := fun a =>
      ne_top_of_le_ne_top ENNReal.one_ne_top (PMF.coe_le_one p a)
    rw [← ENNReal.toReal_sum (fun a _ => h_ne_top a)]
    have hsum : ∑ a : α, p a = 1 :=
      (hasSum_fintype _).unique p.hasSum_coe_one
    rw [hsum]
    simp

/-- Convert a point of the standard simplex on a finite type to a PMF. -/
noncomputable def simplexToPMF {α : Type*} [Fintype α] (s : stdSimplex ℝ α) :
    PMF α :=
  ⟨fun a => ENNReal.ofReal (s.val a), by
    have h : (∑ a : α, ENNReal.ofReal (s.val a)) = 1 := by
      rw [← ENNReal.ofReal_sum_of_nonneg (fun a _ => s.2.1 a), s.2.2]
      exact ENNReal.ofReal_one
    rw [← h]
    exact hasSum_fintype _⟩

/-- Round-trip: `pmfToSimplex ∘ simplexToPMF = id`. -/
lemma pmfToSimplex_simplexToPMF {α : Type*} [Fintype α] (s : stdSimplex ℝ α) :
    pmfToSimplex (simplexToPMF s) = s := by
  apply Subtype.ext
  funext a
  show ((simplexToPMF s) a).toReal = s.val a
  show (ENNReal.ofReal (s.val a)).toReal = s.val a
  exact ENNReal.toReal_ofReal (s.2.1 a)

-- ═══════════════════════════════════════════════════════════
-- Bridge from NormalFormGame to math-xmum's FinGame
-- ═══════════════════════════════════════════════════════════

/-- Convert our `NormalFormGame n` to math-xmum's `FinGame` structure.
    Marked `abbrev` so that `(normalFormGameToFinGame G hn).SS = G.Strategy`
    holds definitionally for typeclass resolution. -/
noncomputable abbrev normalFormGameToFinGame {n : ℕ} (G : NormalFormGame n) (hn : n > 0) :
    FinGame :=
  letI : ∀ i, Nonempty (G.Strategy i) := G.strategyNonempty
  letI : ∀ i, Inhabited (G.Strategy i) := fun i =>
    Classical.inhabited_of_nonempty (G.strategyNonempty i)
  { I := Fin n
    HI := ⟨⟨0, hn⟩⟩
    SS := G.Strategy
    HSS := fun _ => inferInstance
    FinI := inferInstance
    FinSS := fun i => G.strategyFintype i
    g := fun i prof => G.payoff i prof }

-- ═══════════════════════════════════════════════════════════
-- Expected payoff and best response (existing API preserved)
-- ═══════════════════════════════════════════════════════════

/-- Expected payoff for player `i` under a mixed strategy profile. -/
noncomputable def expectedPayoff {n : ℕ} (G : NormalFormGame n)
    (i : Fin n) (σ : MixedStrategyProfile G) : ℝ :=
  letI : ∀ j, Fintype (G.Strategy j) := G.strategyFintype
  letI : DecidableEq (Fin n) := Classical.decEq _
  letI : ∀ j, DecidableEq (G.Strategy j) := fun _ => Classical.decEq _
  ∑ s : ((j : Fin n) → G.Strategy j),
    (∏ j : Fin n, ((σ j).val (s j)).toReal) * G.payoff i s

/-- The best-response correspondence for player `i`. -/
noncomputable def bestResponseCorrespondence {n : ℕ}
    (G : NormalFormGame n) (i : Fin n)
    (σ : MixedStrategyProfile G) : Set (MixedStrategy G i) :=
  { σ_i | ∀ σ_i' : MixedStrategy G i,
    expectedPayoff G i (Function.update σ i σ_i) ≥
    expectedPayoff G i (Function.update σ i σ_i') }

/-- A mixed-strategy Nash equilibrium: each player's mixed strategy is
    a best response to the others. -/
def IsMixedNashEquilibrium {n : ℕ} (G : NormalFormGame n)
    (σ : MixedStrategyProfile G) : Prop :=
  ∀ i : Fin n, σ i ∈ bestResponseCorrespondence G i σ

-- ═══════════════════════════════════════════════════════════
-- Bridge: expectedPayoff = math-xmum's mixed_g
-- ═══════════════════════════════════════════════════════════

/-- The expected payoff in our PMF-based formulation equals math-xmum's
    `mixed_g` after passing through the `pmfToSimplex` bridge. -/
lemma expectedPayoff_eq_mixed_g {n : ℕ} (G : NormalFormGame n) (hn : n > 0)
    (i : Fin n) (σ : MixedStrategyProfile G) :
    expectedPayoff G i σ =
    (normalFormGameToFinGame G hn).mixed_g i (fun j => pmfToSimplex (σ j)) := by
  haveI : ∀ j, Fintype (G.Strategy j) := G.strategyFintype
  haveI : ∀ j, DecidableEq (G.Strategy j) := G.strategyDecEq
  unfold expectedPayoff FinGame.mixed_g
  rfl

-- ═══════════════════════════════════════════════════════════
-- Nash's Theorem
-- ═══════════════════════════════════════════════════════════

/-- Nash's Theorem: every finite normal-form game has at least one
    mixed-strategy Nash equilibrium.

    Closed via math-xmum/Brouwer's `ExistsNashEq`, which itself is
    proved via Scarf's Lemma → Brouwer fixed-point on product simplices.
    Bridged through PMF ↔ stdSimplex conversion. -/
theorem mixed_nash_exists {n : ℕ} (G : NormalFormGame n)
    (hn : n > 0) :
    ∃ σ : MixedStrategyProfile G, IsMixedNashEquilibrium G σ := by
  obtain ⟨τ, hτ⟩ := @ExistsNashEq (normalFormGameToFinGame G hn)
  -- τ : (i : Fin n) → stdSimplex ℝ (G.Strategy i) (via abbrev unfolding)
  refine ⟨fun i => simplexToPMF (τ i), ?_⟩
  intro i σ_i'
  let σ : MixedStrategyProfile G := fun j => simplexToPMF (τ j)
  let y : stdSimplex ℝ (G.Strategy i) := pmfToSimplex σ_i'
  have h_dev := hτ i y
  have h_self_eq : Function.update σ i (σ i) = σ := Function.update_eq_self i σ
  have h_sigma_to_tau : (fun j => pmfToSimplex (σ j)) = τ := by
    funext j
    exact pmfToSimplex_simplexToPMF (τ j)
  have h_dev_to_tau : (fun j => pmfToSimplex (Function.update σ i σ_i' j)) =
      Function.update τ i y := by
    funext j
    by_cases hij : j = i
    · subst hij
      rw [Function.update_self, Function.update_self]
    · rw [Function.update_of_ne hij, Function.update_of_ne hij]
      exact pmfToSimplex_simplexToPMF (τ j)
  show expectedPayoff G i (Function.update σ i (σ i)) ≥
       expectedPayoff G i (Function.update σ i σ_i')
  rw [h_self_eq,
      expectedPayoff_eq_mixed_g G hn i σ,
      expectedPayoff_eq_mixed_g G hn i (Function.update σ i σ_i'),
      h_sigma_to_tau, h_dev_to_tau]
  convert h_dev using 4

end Fulcrum.GameTheory
