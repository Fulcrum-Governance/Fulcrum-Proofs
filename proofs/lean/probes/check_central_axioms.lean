import Lean
import Proofs.BasicInvariants
import Proofs.RLMContracts
import Proofs.TrustTermination
import Proofs.GameTheory.CoordinationEfficiency
import Proofs.GameTheory.NashUniqueness
import Proofs.GameTheory.MixedNashExistence

/-!
Assert the axiom surface of the central public-facing proofs.

Each entry below mirrors the `axiom_profile` recorded in
`claims/theorem_inventory.yaml`; compilation fails on drift in either
direction (a new axiom sneaking in, or a profile shrinking without the
inventory being updated). `#print axioms` lines are kept at the end for
human-readable logs.

Spec drift note: the mixed Nash theorem exported by the repo is
`Fulcrum.GameTheory.mixed_nash_exists`, not
`MixedNashExistence.exists_nash_equilibrium`.
-/

open Lean Elab Command

def axiomsOfCentral (env : Environment) (constName : Name) : Array Name :=
  ((CollectAxioms.collect constName) env |>.run {}).2.axioms

/-- Expected transitive axiom profiles, kept in lockstep with
`claims/theorem_inventory.yaml`. Order inside each set is irrelevant. -/
def expectedProfiles : Array (Name × Array Name) := #[
  (``Fulcrum.GameTheory.constrained_welfare_optimal,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  (``Fulcrum.GameTheory.constrained_poa_exact,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  (``Fulcrum.GameTheory.fulcrum_poa_bounded,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  (``Fulcrum.GameTheory.nash_eq_allModerate,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  (``Fulcrum.GameTheory.mixed_nash_exists,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  (``Fulcrum.budget_safety_guarantee,
    #[``propext]),
  (``Fulcrum.RLM.canAccess,
    #[``Fulcrum.RLM.canAccess]),
  (``Fulcrum.RLM.context_partition_isolation,
    #[``Fulcrum.RLM.canAccess, ``Fulcrum.RLM.context_partition_isolation])
]

elab "#assert_axiom_profiles" : command => do
  let env ← getEnv
  let sortNames (a : Array Name) : Array Name :=
    a.qsort (fun x y => x.toString < y.toString)
  let mut failures : Array String := #[]
  for (t, expected) in expectedProfiles do
    let actual := sortNames (axiomsOfCentral env t)
    let want := sortNames expected
    unless actual == want do
      failures := failures.push
        s!"{t}:\n  inventory: {want.toList}\n  kernel:    {actual.toList}"
  unless failures.isEmpty do
    throwError "axiom-profile drift vs claims/theorem_inventory.yaml:\n{String.intercalate "\n" failures.toList}"
  logInfo s!"[check_central_axioms] {expectedProfiles.size} axiom profiles match inventory"

#assert_axiom_profiles

#print axioms Fulcrum.GameTheory.constrained_welfare_optimal
#print axioms Fulcrum.GameTheory.constrained_poa_exact
#print axioms Fulcrum.GameTheory.fulcrum_poa_bounded
#print axioms Fulcrum.GameTheory.nash_eq_allModerate
#print axioms Fulcrum.GameTheory.mixed_nash_exists
#print axioms Fulcrum.budget_safety_guarantee
#print axioms Fulcrum.RLM.canAccess
#print axioms Fulcrum.RLM.context_partition_isolation
