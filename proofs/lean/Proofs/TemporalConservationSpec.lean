import Proofs.BasicInvariants

namespace Fulcrum

structure Token where
  caps : Caps
  policyVersion : Nat
  expiresAt : Nat

structure GateInput where
  cReq : Caps
  cA : Caps
  now : Nat
  currentPolicyVersion : Nat
  token : Token
  tokenFresh : Bool
  nonceFresh : Bool
  revoked : Bool

def allow (g : GateInput) : Prop :=
  g.cReq ⊆ g.cA
  /\ g.cReq ⊆ g.token.caps
  /\ g.token.policyVersion = g.currentPolicyVersion
  /\ g.now <= g.token.expiresAt
  /\ g.tokenFresh = true
  /\ g.nonceFresh = true
  /\ g.revoked = false

theorem allow_implies_static_subset (g : GateInput) :
  allow g -> g.cReq ⊆ g.cA := by
  intro h
  exact h.1

theorem deny_when_revoked (g : GateInput) :
  g.revoked = true -> (allow g -> False) := by
  intro hRevoked
  intro hAllow
  have hNotRevoked : g.revoked = false := hAllow.2.2.2.2.2.2
  simp [hRevoked] at hNotRevoked

structure TransitionAssumptions where
  perHopRevalidation : Prop
  monotonicPolicyEpoch : Prop
  revocationEnforced : Prop

def Step (g g' : GateInput) : Prop :=
  g'.cReq = g.cReq
  /\ g.cA ⊆ g'.cA
  /\ g.currentPolicyVersion <= g'.currentPolicyVersion
  /\ (g.revoked = true -> g'.revoked = true)

theorem thm_temporal_conservation_spec
  (g g' : GateInput)
  (assumptions : TransitionAssumptions)
  (hPerHop : assumptions.perHopRevalidation)
  (hEpoch : assumptions.monotonicPolicyEpoch)
  (hRev : assumptions.revocationEnforced)
  (hStep : Step g g')
  (hAllow : allow g) :
  g'.cReq ⊆ g'.cA := by
  let _ := hPerHop
  let _ := hEpoch
  let _ := hRev
  rcases hStep with ⟨hReqEq, hMonotoneCap, _hEpochMonotone, _hRevSticky⟩
  intro x hxReqNew
  have hxReqOld : x ∈ g.cReq := by
    simpa [hReqEq] using hxReqNew
  have hxCapOld : x ∈ g.cA := hAllow.1 hxReqOld
  exact hMonotoneCap hxCapOld

theorem thm_temporal_revocation_fail_closed
  (g g' : GateInput)
  (hStep : Step g g')
  (hRevoked : g.revoked = true) :
  allow g' -> False := by
  intro hAllow
  have hStickyRevoked : g'.revoked = true := hStep.2.2.2 hRevoked
  have hNotRevoked : g'.revoked = false := hAllow.2.2.2.2.2.2
  simp [hStickyRevoked] at hNotRevoked

end Fulcrum
