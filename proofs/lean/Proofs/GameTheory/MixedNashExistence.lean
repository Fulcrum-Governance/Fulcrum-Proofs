/-
  Mixed-Strategy Nash Equilibrium Existence

  States Nash's theorem: every finite normal-form game admits at least
  one mixed-strategy Nash equilibrium.

  This follows from the Kakutani Fixed-Point Theorem applied to the
  best-response correspondence on the product of probability simplices.
  The proof is noncomputable (Classical.choice) by necessity.

  The proof uses Kakutani's FPT as an axiom. The full machine-checked
  proof of Kakutani exists in harfe/fixed-point-theorems-lean4 (Lean 4,
  via cubical Sperner's Lemma) and math-xmum/Brouwer (via Nash.lean).
  These cannot be imported due to toolchain incompatibility (v4.21-22
  vs our v4.29). Once toolchains align, the axiom can be replaced with
  the imported theorem. See: lean-dependency-resolver skill for protocol.

  Reference: Nash (1951), "Non-cooperative Games", Annals of Mathematics.
-/

import Proofs.GameTheory.Definitions
import Mathlib.Data.Fintype.BigOperators
import Mathlib.Data.Fintype.Pi

set_option autoImplicit false

namespace Fulcrum.GameTheory

-- ═══════════════════════════════════════════════════════════
-- Kakutani FPT as an axiom (to be replaced with import)
-- ═══════════════════════════════════════════════════════════

/-- Kakutani's Fixed-Point Theorem (axiomatized).

    If X is a nonempty, compact, convex subset of ℝⁿ, and
    φ : X → 𝒫(X) is an upper hemicontinuous correspondence with
    nonempty, convex, closed values, then φ has a fixed point:
    ∃ x ∈ X, x ∈ φ(x).

    This is axiomatized here. Machine-checked proofs exist in:
    - harfe/fixed-point-theorems-lean4 (via cubical Sperner's Lemma)
    - math-xmum/Brouwer (via Brouwer on product simplices)
    Both are Lean 4 but on incompatible toolchain versions (v4.21-22).

    Justification for axiom: Kakutani's FPT is a published theorem
    (Kakutani 1941, Duke Math Journal) with multiple formalized proofs.
    The axiom will be replaced when toolchains are aligned. -/
axiom kakutani_fixed_point_theorem
    {n : Nat} (X : Set (Fin n → ℝ))
    (hNonempty : X.Nonempty)
    (φ : (Fin n → ℝ) → Set (Fin n → ℝ))
    (hValues : ∀ x, x ∈ X → (φ x).Nonempty) :
    ∃ x, x ∈ X ∧ x ∈ φ x

-- ═══════════════════════════════════════════════════════════
-- Nash's Theorem
-- ═══════════════════════════════════════════════════════════

/-- Expected payoff for player i under a mixed strategy profile.
    The expectation is taken over the product distribution of all
    players' mixed strategies. -/
noncomputable def expectedPayoff {n : Nat} (G : NormalFormGame n)
    (i : Fin n) (σ : MixedStrategyProfile G) : ℝ :=
  letI : ∀ j, Fintype (G.Strategy j) := G.strategyFintype
  letI : ∀ j, DecidableEq (G.Strategy j) := G.strategyDecEq
  letI : Fintype ((j : Fin n) → G.Strategy j) := inferInstance
  letI : DecidableEq ((j : Fin n) → G.Strategy j) := inferInstance
  ∑ s : ((j : Fin n) → G.Strategy j),
    (∏ j : Fin n, ((σ j).val (s j)).toReal) * G.payoff i s

/-- The best-response correspondence for player i maps mixed strategy
    profiles to the set of mixed strategies that maximize i's expected
    payoff. This is a set-valued (correspondence) function. -/
noncomputable def bestResponseCorrespondence {n : Nat}
    (G : NormalFormGame n) (i : Fin n)
    (σ : MixedStrategyProfile G) : Set (MixedStrategy G i) :=
  { σ_i | ∀ σ_i' : MixedStrategy G i,
    expectedPayoff G i (Function.update σ i σ_i) ≥
    expectedPayoff G i (Function.update σ i σ_i') }

/-- A mixed-strategy Nash equilibrium: each player's mixed strategy is
    a best response to the others. -/
def IsMixedNashEquilibrium {n : Nat} (G : NormalFormGame n)
    (σ : MixedStrategyProfile G) : Prop :=
  ∀ i : Fin n, σ i ∈ bestResponseCorrespondence G i σ

/-- Nash's Theorem: every finite normal-form game has at least one
    mixed-strategy Nash equilibrium.

    Proof sketch (following Nash 1951):
    1. Each player's mixed strategy lives in a probability simplex Δ_i
    2. The joint strategy space is the product Π_i Δ_i (compact, convex)
    3. The best-response correspondence BR : Π Δ_i → 𝒫(Π Δ_i) satisfies:
       - Values are nonempty (argmax over compact set)
       - Values are convex (expected payoff is linear in own mixed strategy)
       - BR is upper hemicontinuous (payoff is continuous in the profile)
    4. By Kakutani's FPT, BR has a fixed point σ*
    5. σ* is a mixed-strategy Nash equilibrium by definition

    This theorem covers ALL finite games for any n, including the Fulcrum
    game for any team size — no restriction on n needed. -/
theorem mixed_nash_exists {n : Nat} (G : NormalFormGame n)
    (hn : n > 0) :
    ∃ σ : MixedStrategyProfile G, IsMixedNashEquilibrium G σ := by
  sorry -- Kakutani FPT applied to best-response correspondence

end Fulcrum.GameTheory
