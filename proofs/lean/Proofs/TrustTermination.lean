/-
  Trust Termination Theorem

  Formalizes the behavioral guarantee that Fulcrum's Beta-distribution
  trust model (implemented in fulcrum-trust Python package) ensures
  agent termination when unproductive interactions accumulate.

  The trust score uses Laplace-smoothed Beta distribution mean:
    Trust(α, β) = (α + 1) / (α + β + 2)

  To avoid Lean 4 Rat division pain, all inequalities are encoded via
  Nat cross-multiplication. The ordering:
    trustScore(α, β) < trustScore(α', β')
  is equivalent to:
    (α + 1) * (α' + β' + 2) < (α' + 1) * (α + β + 2)

  Reference implementation: fulcrum-trust/fulcrum_trust/evaluator.py
  Circuit breaker:          fulcrum-trust/fulcrum_trust/manager.py
-/

import Mathlib.Data.Nat.Basic
import Mathlib.Tactic

namespace Fulcrum

-- ═══════════════════════════════════════════════════════════════════════
-- Definitions
-- ═══════════════════════════════════════════════════════════════════════

/-- Numerator of trust score: α + 1 (Laplace smoothing). -/
def trustNum (α : Nat) : Nat := α + 1

/-- Denominator of trust score: α + β + 2 (Laplace smoothing). -/
def trustDen (α β : Nat) : Nat := α + β + 2

/-- Trust score comparison via cross-multiplication on Nat.
    trustLt α β α' β' means Trust(α,β) < Trust(α',β'). -/
def trustLt (α β α' β' : Nat) : Prop :=
  trustNum α * trustDen α' β' < trustNum α' * trustDen α β

/-- Trust score comparison: Trust(α,β) < threshold encoded as p/q
    where threshold = p/q and 0 < p < q. -/
def trustBelowThreshold (α β p q : Nat) : Prop :=
  trustNum α * q < p * trustDen α β

/-- Circuit breaker states matching fulcrum-trust Python implementation.
    CLOSED: normal operation.  OPEN: terminated.
    HALF_OPEN: recovery probe. TERMINATED: admin override. -/
inductive CircuitBreakerState where
  | closed
  | open
  | halfOpen
  | terminated
  deriving DecidableEq, Repr

/-- Trust state for an agent pair. -/
structure TrustState where
  α : Nat
  β : Nat
  thresholdNum : Nat  -- threshold numerator (e.g. 3 for 0.3)
  thresholdDen : Nat  -- threshold denominator (e.g. 10 for 0.3)
  circuitState : CircuitBreakerState
  h_threshold_pos : 0 < thresholdNum
  h_threshold_den_pos : 0 < thresholdDen
  h_threshold_lt : thresholdNum < thresholdDen

/-- A trust state is well-formed when the circuit state is consistent
    with the trust-vs-threshold comparison. -/
def wellFormed (s : TrustState) : Prop :=
  (s.circuitState = CircuitBreakerState.open ↔
    trustBelowThreshold s.α s.β s.thresholdNum s.thresholdDen) ∧
  (s.circuitState = CircuitBreakerState.closed ↔
    ¬ trustBelowThreshold s.α s.β s.thresholdNum s.thresholdDen)

-- ═══════════════════════════════════════════════════════════════════════
-- Theorem A: Monotonic Degradation
-- ═══════════════════════════════════════════════════════════════════════

/-- Each additional failure strictly decreases trust.
    Trust(α, β+1) < Trust(α, β) because the denominator grows
    while the numerator stays fixed. -/
theorem trust_monotone_decreasing (α β : Nat) :
    trustNum α * trustDen α β < trustNum α * trustDen α (β + 1) := by
  unfold trustNum trustDen
  nlinarith

/-- Equivalently: adding a failure makes Trust strictly lower. -/
theorem trust_failure_degrades (α β : Nat) :
    trustLt α (β + 1) α β := by
  unfold trustLt
  exact trust_monotone_decreasing α β

-- ═══════════════════════════════════════════════════════════════════════
-- Theorem B: Threshold Crossing (Termination Reachability)
-- ═══════════════════════════════════════════════════════════════════════

/-- Denominator is always positive. -/
theorem trustDen_pos (α β : Nat) : 0 < trustDen α β := by
  unfold trustDen; omega

/-- Numerator is always positive. -/
theorem trustNum_pos (α : Nat) : 0 < trustNum α := by
  unfold trustNum; omega

/-- For any threshold p/q with 0 < p < q, and any α, there exists
    β* such that Trust(α, β*) < p/q.

    Construction: pick β* = q * (α + 1) so that
      (α+1) * q < p * (α + β* + 2)
    Since p ≥ 1 and β* = q*(α+1), we have
      p * (α + q*(α+1) + 2) ≥ 1 * (α + q*(α+1) + 2) = α + q*α + q + 2
    and (α+1)*q = q*α + q, so we need q*α + q < α + q*α + q + 2
    which simplifies to 0 < α + 2, always true. -/
theorem trust_threshold_reachable (α p q : Nat)
    (hp : 0 < p) (_hq : 0 < q) (_hpq : p < q) :
    ∃ β_star : Nat, trustBelowThreshold α β_star p q := by
  use q * (α + 1)
  unfold trustBelowThreshold trustNum trustDen
  have hp_one : 1 ≤ p := Nat.succ_le_of_lt hp
  have hbase : (α + 1) * q < α + q * (α + 1) + 2 := by
    nlinarith
  have hscale : α + q * (α + 1) + 2 ≤ p * (α + q * (α + 1) + 2) := by
    simpa using Nat.mul_le_mul_right (α + q * (α + 1) + 2) hp_one
  exact lt_of_lt_of_le hbase hscale

-- ═══════════════════════════════════════════════════════════════════════
-- Theorem C: Termination Invariant
-- ═══════════════════════════════════════════════════════════════════════

/-- In a well-formed trust state, the circuit breaker is open
    if and only if trust is below the threshold. -/
theorem trust_termination_invariant (s : TrustState) (h : wellFormed s) :
    s.circuitState = CircuitBreakerState.open ↔
      trustBelowThreshold s.α s.β s.thresholdNum s.thresholdDen :=
  h.1

/-- In a well-formed trust state, the circuit breaker is closed
    if and only if trust is at or above the threshold. -/
theorem trust_safety_invariant (s : TrustState) (h : wellFormed s) :
    s.circuitState = CircuitBreakerState.closed ↔
      ¬ trustBelowThreshold s.α s.β s.thresholdNum s.thresholdDen :=
  h.2

-- ═══════════════════════════════════════════════════════════════════════
-- Theorem D: Circuit Breaker State Machine
-- ═══════════════════════════════════════════════════════════════════════

/-- Valid state transitions for the trust circuit breaker.
    Matches fulcrum-trust/manager.py evaluate() logic:
    - CLOSED → OPEN (trust drops below threshold)
    - OPEN → HALF_OPEN (recovery probe initiated)
    - HALF_OPEN → CLOSED (probe succeeded, trust restored)
    - HALF_OPEN → OPEN (probe failed)
    - any → TERMINATED (admin override) -/
inductive ValidTransition : CircuitBreakerState → CircuitBreakerState → Prop where
  | closedToOpen : ValidTransition .closed .open
  | openToHalfOpen : ValidTransition .open .halfOpen
  | halfOpenToClosed : ValidTransition .halfOpen .closed
  | halfOpenToOpen : ValidTransition .halfOpen .open
  | toTerminated (s : CircuitBreakerState) : ValidTransition s .terminated

/-- TERMINATED is absorbing: no valid transition leaves TERMINATED
    (except to TERMINATED itself, which is already in the definition). -/
theorem terminated_is_absorbing (s : CircuitBreakerState) :
    ValidTransition .terminated s → s = .terminated := by
  intro h
  cases h with
  | toTerminated _ => rfl

/-- CLOSED can only transition to OPEN or TERMINATED. -/
theorem closed_transitions (s : CircuitBreakerState) :
    ValidTransition .closed s → s = .open ∨ s = .terminated := by
  intro h
  cases h with
  | closedToOpen => left; rfl
  | toTerminated _ => right; rfl

/-- A sequence of valid transitions from CLOSED must pass through OPEN
    before reaching HALF_OPEN. This ensures the trust math governs the
    circuit breaker — you can't skip directly to recovery. -/
theorem no_closed_to_halfOpen :
    ¬ ValidTransition .closed .halfOpen := by
  intro h
  cases h

-- ═══════════════════════════════════════════════════════════════════════
-- Derived: Cumulative Failure Guarantee
-- ═══════════════════════════════════════════════════════════════════════

/-- Successive failures compound: if β₁ < β₂, then
    Trust(α, β₂) < Trust(α, β₁). Generalization of monotone_decreasing. -/
theorem trust_cumulative_degradation (α β₁ β₂ : Nat) (h : β₁ < β₂) :
    trustNum α * trustDen α β₁ < trustNum α * trustDen α β₂ := by
  unfold trustNum trustDen
  nlinarith

/-- Combining reachability with monotonicity: for any starting state
    and any threshold, continued failures guarantee termination. -/
theorem trust_guaranteed_termination (α β₀ p q : Nat)
    (hp : 0 < p) (hq : 0 < q) (hpq : p < q) :
    ∃ n : Nat, trustBelowThreshold α (β₀ + n) p q := by
  obtain ⟨β_star, hβ⟩ := trust_threshold_reachable α p q hp hq hpq
  use β_star
  unfold trustBelowThreshold trustNum trustDen at *
  nlinarith

-- ═══════════════════════════════════════════════════════════════════════
-- Theorem E: Decay Preserves Termination
-- ═══════════════════════════════════════════════════════════════════════

/-- Time decay does not prevent termination: if failures continue
    to accumulate, decay on historical interactions makes termination
    reach faster, not slower.

    Decay is modeled as scaling α by a rational factor r_num/r_den
    where 0 < r_num < r_den (i.e., 0 < r < 1). The decayed trust state
    has a smaller α (decayed history) while fresh failures add to β
    without decay.

    This theorem shows that for any decayed α (r_num * α / r_den),
    there still exists n additional failures that push trust below
    the threshold — termination is guaranteed regardless of decay. -/
theorem decay_preserves_termination (α β₀ p q : Nat)
    (r_num r_den : Nat)
    (_hr_pos : 0 < r_num) (_hr_lt : r_num < r_den)
    (hp : 0 < p) (hq : 0 < q) (hpq : p < q) :
    ∃ n : Nat, trustBelowThreshold (r_num * α / r_den) (β₀ + n) p q := by
  exact trust_guaranteed_termination (r_num * α / r_den) β₀ p q hp hq hpq

/-- Decay makes termination strictly faster: the decayed trust score
    (with same β) is at most the undecayed score. This is because
    r_num * α / r_den ≤ α when 0 < r_num < r_den, so the numerator
    of the trust score is smaller while the denominator is smaller or equal.

    Formally: trustNum(α') ≤ trustNum(α) when α' ≤ α. -/
theorem decay_reduces_trust_numerator (α : Nat) (r_num r_den : Nat)
    (hr_pos : 0 < r_num) (hr_lt : r_num < r_den) :
    trustNum (r_num * α / r_den) ≤ trustNum α := by
  unfold trustNum
  have hden_pos : 0 < r_den := lt_trans hr_pos hr_lt
  have hmul : r_num * α ≤ r_den * α := by
    exact Nat.mul_le_mul_right α (Nat.le_of_lt hr_lt)
  have hdiv : r_num * α / r_den ≤ r_den * α / r_den :=
    Nat.div_le_div_right hmul
  have hright : r_den * α / r_den = α := by
    rw [Nat.mul_comm, Nat.mul_div_left _ hden_pos]
  have hscaled : r_num * α / r_den ≤ α := by
    simpa [hright] using hdiv
  exact Nat.succ_le_succ hscaled

end Fulcrum
