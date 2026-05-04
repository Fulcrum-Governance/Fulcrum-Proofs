import Proofs.BasicInvariants
import Proofs.RLMContracts
import Proofs.TrustTermination
import Proofs.GameTheory.CoordinationEfficiency
import Proofs.GameTheory.NashUniqueness
import Proofs.GameTheory.MixedNashExistence

/-!
Probe the current axiom surface of the central public-facing proofs.

Spec drift note: the mixed Nash theorem exported by the repo is
`Fulcrum.GameTheory.mixed_nash_exists`, not
`MixedNashExistence.exists_nash_equilibrium`.
-/

#print axioms Fulcrum.GameTheory.constrained_welfare_optimal
#print axioms Fulcrum.GameTheory.constrained_poa_exact
#print axioms Fulcrum.GameTheory.fulcrum_poa_bounded
#print axioms Fulcrum.GameTheory.nash_eq_allModerate
#print axioms Fulcrum.GameTheory.mixed_nash_exists
#print axioms Fulcrum.budget_safety_guarantee
#print axioms Fulcrum.RLM.canAccess
#print axioms Fulcrum.RLM.context_partition_isolation
