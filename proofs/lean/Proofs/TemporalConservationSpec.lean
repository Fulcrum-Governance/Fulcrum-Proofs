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
  exact Bool.noConfusion (Eq.trans hRevoked hNotRevoked)

end Fulcrum
