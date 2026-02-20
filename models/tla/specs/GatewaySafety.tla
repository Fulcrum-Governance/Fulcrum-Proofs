------------------------------ MODULE GatewaySafety ------------------------------
EXTENDS Naturals, FiniteSets, TLC

CONSTANT CapA, CapReq

VARIABLES tokenFresh, policyEpochOk, revoked, allow

Init ==
  /\ tokenFresh = TRUE
  /\ policyEpochOk = TRUE
  /\ revoked = FALSE
  /\ allow = (CapReq \subseteq CapA)

Step ==
  /\ tokenFresh' \in BOOLEAN
  /\ policyEpochOk' \in BOOLEAN
  /\ revoked' \in BOOLEAN
  /\ allow' = (CapReq \subseteq CapA)
             /\ tokenFresh'
             /\ policyEpochOk'
             /\ ~revoked'

Next == Step

Spec == Init /\ [][Next]_<<tokenFresh, policyEpochOk, revoked, allow>>

NoUnauthorizedCapability ==
  allow => (CapReq \subseteq CapA)

FailClosedOnInvalidContext ==
  (~tokenFresh \/ ~policyEpochOk \/ revoked) => ~allow

=============================================================================
