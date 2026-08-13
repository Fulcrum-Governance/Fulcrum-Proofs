import Lean
import Proofs.BasicInvariants
import Proofs.RLMContracts
import Proofs.TrustTermination
import Proofs.KernelVariants
import Proofs.GovernedKernel
import Proofs.GameTheory.CoordinationEfficiency
import Proofs.GameTheory.CoordinationCorrespondence
import Proofs.GameTheory.CoordinationEfficiencyInt
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
  -- Canonical exact-data claim: complete six-clause result, kernel-1.
  (``Fulcrum.GameTheory.constrained_poa_exact, #[``propext]),
  -- Noncanonical Real compatibility/provenance theorem.
  (``Fulcrum.GameTheory.constrained_poa_exact_real_compat,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  -- Downstream correspondence roots; never imported by the canonical cone.
  (``Fulcrum.GameTheory.exactFullClaim_iff_realFullClaim,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  (``Fulcrum.GameTheory.exactCompleteDomain_iff_realCompleteDomain,
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
    #[``Fulcrum.RLM.canAccess, ``Fulcrum.RLM.context_partition_isolation]),
  -- Ported kernel-supplement modules (Zenodo DOI 10.5281/zenodo.19900714)
  (``Fulcrum.capped_success_update_bounded, #[``propext]),
  (``Fulcrum.capped_prior_strict_responsiveness,
    #[``propext, ``Classical.choice, ``Quot.sound]),
  (``Fulcrum.open_circuit_blocks_before_budget, #[``propext]),
  (``Fulcrum.governed_execution_preserves_budget, #[``propext]),
  (``Fulcrum.governed_kernel_pre_execution_safety, #[``propext]),
  (``Fulcrum.high_risk_execution_requires_stronger_trust, #[``propext]),
  (``Fulcrum.high_risk_execution_kernel_guarantee, #[``propext]),
  (``Fulcrum.guarded_monotone_resource, #[``propext]),
  -- Integer-audit companion (choice-free; Quot.sound via omega reflection)
  (``Fulcrum.GameTheory.netQuality15_spec, #[``propext]),
  (``Fulcrum.GameTheory.netQuality15_le_linear, #[``propext, ``Quot.sound]),
  (``Fulcrum.GameTheory.welfare15_le_linear, #[``propext, ``Quot.sound]),
  (``Fulcrum.GameTheory.constrained_welfare_optimal_int,
    #[``propext, ``Quot.sound]),
  (``Fulcrum.GameTheory.allModerate_welfare15, #[``propext, ``Quot.sound]),
  (``Fulcrum.GameTheory.allModerate_cost_int, #[``propext, ``Quot.sound]),
  (``Fulcrum.GameTheory.constrained_poa_exact_int,
    #[``propext, ``Quot.sound])
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
#print axioms Fulcrum.GameTheory.constrained_poa_exact_real_compat
#print axioms Fulcrum.GameTheory.exactFullClaim_iff_realFullClaim
#print axioms Fulcrum.GameTheory.exactCompleteDomain_iff_realCompleteDomain
#print axioms Fulcrum.GameTheory.fulcrum_poa_bounded
#print axioms Fulcrum.GameTheory.nash_eq_allModerate
#print axioms Fulcrum.GameTheory.mixed_nash_exists
#print axioms Fulcrum.budget_safety_guarantee
#print axioms Fulcrum.RLM.canAccess
#print axioms Fulcrum.RLM.context_partition_isolation
#print axioms Fulcrum.capped_prior_strict_responsiveness
#print axioms Fulcrum.governed_kernel_pre_execution_safety
#print axioms Fulcrum.high_risk_execution_kernel_guarantee
#print axioms Fulcrum.GameTheory.constrained_poa_exact_int
