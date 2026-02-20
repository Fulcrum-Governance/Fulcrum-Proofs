------------------------------ MODULE GatewaySafety ------------------------------
EXTENDS Naturals, FiniteSets, Sequences, TLC

CONSTANTS Nodes, CapA, CapReq, MaxEpochSkew, MaxPropagationDelay, MaxEpochValue

VARIABLES policyEpoch, nodeEpoch, tokenEpoch, revoked, tokenFresh, nonceFresh, replaySeen, propagationDelay, clockSkew, allow

Vars == <<policyEpoch, nodeEpoch, tokenEpoch, revoked, tokenFresh, nonceFresh, replaySeen, propagationDelay, clockSkew, allow>>

NodeEpochType(pe) == [Nodes -> 0..(pe + MaxEpochSkew)]
ClockSkewType == [Nodes -> 0..MaxEpochSkew]

AllNodesAtOrAbove(e, ne) == \A n \in Nodes : ne[n] >= e

GateAllow(tokenEpochValue, ne, revokedValue, tokenFreshValue, nonceFreshValue, replaySeenValue, delayValue) ==
  /\ CapReq \subseteq CapA
  /\ tokenFreshValue
  /\ nonceFreshValue
  /\ ~revokedValue
  /\ ~replaySeenValue
  /\ delayValue <= MaxPropagationDelay
  /\ AllNodesAtOrAbove(tokenEpochValue, ne)

Init ==
  /\ policyEpoch = 0
  /\ nodeEpoch = [n \in Nodes |-> 0]
  /\ tokenEpoch = 0
  /\ revoked = FALSE
  /\ tokenFresh = TRUE
  /\ nonceFresh = TRUE
  /\ replaySeen = FALSE
  /\ propagationDelay = 0
  /\ clockSkew = [n \in Nodes |-> 0]
  /\ allow = GateAllow(tokenEpoch, nodeEpoch, revoked, tokenFresh, nonceFresh, replaySeen, propagationDelay)

Step ==
  \E pe \in 0..MaxEpochValue:
    \E ne \in NodeEpochType(pe):
      \E te \in 0..pe:
        \E rv \in BOOLEAN:
          \E tf \in BOOLEAN:
            \E nf \in BOOLEAN:
              \E rs \in BOOLEAN:
                \E pd \in 0..MaxPropagationDelay:
                  \E cs \in ClockSkewType:
                    /\ policyEpoch' = pe
                    /\ nodeEpoch' = ne
                    /\ tokenEpoch' = te
                    /\ revoked' = rv
                    /\ tokenFresh' = tf
                    /\ nonceFresh' = nf
                    /\ replaySeen' = rs
                    /\ propagationDelay' = pd
                    /\ clockSkew' = cs
                    /\ allow' = GateAllow(tokenEpoch', nodeEpoch', revoked', tokenFresh', nonceFresh', replaySeen', propagationDelay')

Next == Step

Spec == Init /\ [][Next]_Vars

NoUnauthorizedCapability ==
  allow => (CapReq \subseteq CapA)

FailClosedOnInvalidContext ==
  (~tokenFresh \/ ~nonceFresh \/ revoked \/ replaySeen) => ~allow

BoundedEpochSkew ==
  \A n \in Nodes : nodeEpoch[n] <= policyEpoch + MaxEpochSkew

ReplayDenied ==
  replaySeen => ~allow

RevocationFailClosed ==
  revoked => ~allow

FreshnessRequired ==
  ~tokenFresh => ~allow

NonceRequired ==
  ~nonceFresh => ~allow

=============================================================================
