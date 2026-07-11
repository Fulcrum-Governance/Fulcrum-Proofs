/-
  Capped-Prior Trust Variant (published kernel-supplement module)

  Ported from the released D4 supplement `d4-kernel-supplement.zip`
  (Zenodo record DOI 10.5281/zenodo.19900714, published 2026-04-30),
  where this module backs the paper's Theorem 3.9, "Strict Responsiveness
  Bound for the Capped Variant". Port deltas versus the published bytes:
  this provenance header and the import path
  (`TrustTermination` → `Proofs.TrustTermination`); declarations are
  verbatim.

  Scope, in the paper's own words: "This capped-prior result is a hardened
  model variant, not a claim about the current implementation." The
  deployed Python estimator (fulcrum-trust) uses raw α/(α+β) over floats
  and has a different (tighter, minimal) detection constant than the
  sufficient Lean witness q·(αMax+1) — see the CORRESPONDENCE note on
  THM-TRUST-DETECTION-BOUND in claims/theorem_inventory.yaml before citing
  either constant.
-/

import Mathlib.Tactic
import Proofs.TrustTermination

namespace Fulcrum

/-- Hardened trust variant: accumulated successes are capped. -/
def cappedSuccessUpdate (α αMax : Nat) : Nat :=
  min (α + 1) αMax

/-- The capped-success update never exceeds the configured cap. -/
theorem capped_success_update_bounded (α αMax : Nat) :
    cappedSuccessUpdate α αMax <= αMax := by
  unfold cappedSuccessUpdate
  exact Nat.min_le_right _ _

/-- In the capped model, the threshold-crossing delay is uniformly
    bounded by the configured cap rather than the full accumulated
    success history. -/
theorem capped_prior_strict_responsiveness
    (α αMax β₀ p q : Nat)
    (hα : α <= αMax)
    (hp : 0 < p) (_hq : 0 < q) (_hpq : p < q) :
    ∃ n : Nat, n <= q * (αMax + 1) ∧ trustBelowThreshold α (β₀ + n) p q := by
  refine ⟨q * (α + 1), ?_, ?_⟩
  · exact Nat.mul_le_mul_left q (Nat.succ_le_succ hα)
  · unfold trustBelowThreshold trustNum trustDen
    have hp_one : 1 <= p := Nat.succ_le_of_lt hp
    have hbase : (α + 1) * q < α + (β₀ + q * (α + 1)) + 2 := by
      nlinarith
    have hscale :
        α + (β₀ + q * (α + 1)) + 2 <=
          p * (α + (β₀ + q * (α + 1)) + 2) := by
      simpa using Nat.mul_le_mul_right
        (α + (β₀ + q * (α + 1)) + 2) hp_one
    exact lt_of_lt_of_le hbase hscale

end Fulcrum
