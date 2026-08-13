import Lean
import Proofs.GameTheory.CoordinationCorrespondence
import Proofs.GameTheory.CoordinationEfficiencyInt

/-!
Fail-closed axiom profiles for FUL-502.

The exact owner cone is checked declaration-by-declaration at kernel-1.  The
legacy Real compatibility theorem and every named correspondence theorem are
measured separately, so their kernel-3 support cannot be mistaken for a
canonical dependency.
-/

open Lean Elab Command

def axiomsOfExactPoA (env : Environment) (constName : Name) : Array Name :=
  ((CollectAxioms.collect constName) env |>.run {}).2.axioms

def canonicalKernel0 : Array Name := #[
  ``Fulcrum.GameTheory.SignedNat.zero_pos,
  ``Fulcrum.GameTheory.SignedNat.zero_neg,
  ``Fulcrum.GameTheory.SignedNat.add_pos,
  ``Fulcrum.GameTheory.SignedNat.add_neg,
  ``Fulcrum.GameTheory.SignedNat.nsmul_pos,
  ``Fulcrum.GameTheory.SignedNat.nsmul_neg,
  ``Fulcrum.GameTheory.exactUpdate_same,
  ``Fulcrum.GameTheory.exactUpdate_of_ne
]

/-- Every theorem in the five canonical exact owner modules. -/
def canonicalKernel1 : Array Name := #[
  ``Fulcrum.GameTheory.exactRoster_length,
  ``Fulcrum.GameTheory.exactRoster_get,
  ``Fulcrum.GameTheory.structuralSum_const,
  ``Fulcrum.GameTheory.structuralSum_const_value,
  ``Fulcrum.GameTheory.structuralSum_const_fn,
  ``Fulcrum.GameTheory.structuralSum_comp,
  ``Fulcrum.GameTheory.structuralSum_index,
  ``Fulcrum.GameTheory.structuralSum_pointwise,
  ``Fulcrum.GameTheory.structuralSum_congr,
  ``Fulcrum.GameTheory.structuralSum_le,
  ``Fulcrum.GameTheory.structuralSum_add,
  ``Fulcrum.GameTheory.structuralSum_mul_left,
  ``Fulcrum.GameTheory.structuralUpdate_tail,
  ``Fulcrum.GameTheory.structuralSum_update_general,
  ``Fulcrum.GameTheory.exactTotalTokens_update_general,
  ``Fulcrum.GameTheory.exactAllModerate_totalTokens,
  ``Fulcrum.GameTheory.structuralSum_lookup_le,
  ``Fulcrum.GameTheory.exactActionCount_pos_of_lookup,
  ``Fulcrum.GameTheory.exactActionCount_lookup_of_pos,
  ``Fulcrum.GameTheory.exactActionCount_eq_zero_of_forall_ne,
  ``Fulcrum.GameTheory.exactActionCount_partition,
  ``Fulcrum.GameTheory.exactTotalTokens_count_formula,
  ``Fulcrum.GameTheory.exactTotalQuality_count_formula,
  ``Fulcrum.GameTheory.exactTotalPenalty_count_formula,
  ``Fulcrum.GameTheory.exactTotalTokens_balance_no_noncompliant,
  ``Fulcrum.GameTheory.exactOverflow_eq_zero_of_le,
  ``Fulcrum.GameTheory.exactOverflow_add_budget_of_lt,
  ``Fulcrum.GameTheory.exactOverflow_mono,
  ``Fulcrum.GameTheory.exactAllModerate_overflow_eq_zero,
  ``Fulcrum.GameTheory.exactAllModerate_payoffNumerator,
  ``Fulcrum.GameTheory.exactAllModerate_aggressive_overflow,
  ``Fulcrum.GameTheory.exactAggressive_deviation_bound,
  ``Fulcrum.GameTheory.exactAllModerate_isNash,
  ``Fulcrum.GameTheory.exactNash_moderate_deviation_bound,
  ``Fulcrum.GameTheory.exactNoncompliant_moderate_total,
  ``Fulcrum.GameTheory.exactNoNoncompliant_inNash,
  ``Fulcrum.GameTheory.exactAggressive_moderate_total,
  ``Fulcrum.GameTheory.exactConservative_moderate_total,
  ``Fulcrum.GameTheory.exactAggressive_deviation_strict,
  ``Fulcrum.GameTheory.exactOverflow_count_contradiction,
  ``Fulcrum.GameTheory.exactNoOverflow_inNash,
  ``Fulcrum.GameTheory.exactConservative_count_contradiction,
  ``Fulcrum.GameTheory.exactNoConservative_inNash,
  ``Fulcrum.GameTheory.exactNoAggressive_inFeasibleBalanced,
  ``Fulcrum.GameTheory.exactNash_eq_allModerate,
  ``Fulcrum.GameTheory.structuralSignedSum_components,
  ``Fulcrum.GameTheory.exactWelfareNumerator_components,
  ``Fulcrum.GameTheory.exactAction_supporting_inequality,
  ``Fulcrum.GameTheory.exactSupporting_inequality,
  ``Fulcrum.GameTheory.exactFeasible_quality_bound,
  ``Fulcrum.GameTheory.exactAllModerate_feasible,
  ``Fulcrum.GameTheory.exactAllModerate_welfareNumerator,
  ``Fulcrum.GameTheory.exactConstrained_welfare_optimal,
  ``Fulcrum.GameTheory.exactConstrained_poa_one,
  ``Fulcrum.GameTheory.constrained_poa_exact
]

def correspondenceKernel0 : Array Name := #[
  ``Fulcrum.GameTheory.exactActionCost_eq_actionTokenCost,
  ``Fulcrum.GameTheory.exactActionQuality_eq_actionQuality,
  ``Fulcrum.GameTheory.exactViolationPenalty_eq_violationPenalty,
  ``Fulcrum.GameTheory.exactUpdate_eq_functionUpdate,
  ``Fulcrum.GameTheory.correspondenceUpdate_changed,
  ``Fulcrum.GameTheory.correspondenceUpdate_unchanged,
  ``Fulcrum.GameTheory.exactAllModerate_profile
]

def correspondenceKernel1 : Array Name := #[
  ``Fulcrum.GameTheory.exactActionViolates_eq_actionViolates,
  ``Fulcrum.GameTheory.exactActionPenalty_eq_legacyPenalty,
  ``Fulcrum.GameTheory.correspondenceRoster_length,
  ``Fulcrum.GameTheory.correspondenceRoster_get,
  ``Fulcrum.GameTheory.exactAllModerate_existence_and_uniqueness
]

def correspondenceKernel3 : Array Name := #[
  ``Fulcrum.GameTheory.constrained_poa_exact_real_compat,
  ``Fulcrum.GameTheory.structuralSum_eq_finsetSum,
  ``Fulcrum.GameTheory.exactTotalTokens_eq_totalTokens,
  ``Fulcrum.GameTheory.signedNatValue_add,
  ``Fulcrum.GameTheory.signedNat_le_iff_real_le,
  ``Fulcrum.GameTheory.exactOverflow_share_eq_legacy,
  ``Fulcrum.GameTheory.exactPayoff_value,
  ``Fulcrum.GameTheory.exactPayoff_value_noOverflow,
  ``Fulcrum.GameTheory.exactPayoff_value_overflow,
  ``Fulcrum.GameTheory.exactPayoff_le_iff_realPayoff_le,
  ``Fulcrum.GameTheory.exactWithinBudget_iff_withinBudget,
  ``Fulcrum.GameTheory.exactIsNash_iff_isNashEquilibrium,
  ``Fulcrum.GameTheory.structuralSignedSum_value,
  ``Fulcrum.GameTheory.exactWelfare_value,
  ``Fulcrum.GameTheory.exactWelfare_le_iff_realWelfare_le,
  ``Fulcrum.GameTheory.exactAllModerate_cost,
  ``Fulcrum.GameTheory.exactAllModerate_feasibility_iff,
  ``Fulcrum.GameTheory.exactAllModerate_feasibility,
  ``Fulcrum.GameTheory.exactAllModerate_payoff,
  ``Fulcrum.GameTheory.exactAllModerate_welfare,
  ``Fulcrum.GameTheory.exactAllModerate_nash_iff_real,
  ``Fulcrum.GameTheory.exactNashUniqueness_iff_real,
  ``Fulcrum.GameTheory.realFullClaim,
  ``Fulcrum.GameTheory.exactFullClaim_iff_realFullClaim,
  ``Fulcrum.GameTheory.exactCompleteDomain_iff_realCompleteDomain
]

elab "#assert_exact_poa_axiom_profiles" : command => do
  let env ← getEnv
  let sortNames (a : Array Name) : Array Name :=
    a.qsort (fun x y => x.toString < y.toString)
  let groups : Array (String × Array Name × Array Name) := #[
    ("canonical kernel-0", canonicalKernel0, #[]),
    ("canonical kernel-1", canonicalKernel1, #[``propext]),
    ("correspondence kernel-0", correspondenceKernel0, #[]),
    ("correspondence kernel-1", correspondenceKernel1, #[``propext]),
    ("correspondence/compatibility kernel-3", correspondenceKernel3,
      #[``propext, ``Classical.choice, ``Quot.sound])
  ]
  let mut failures : Array String := #[]
  let mut checked := 0
  for (label, declarations, expected) in groups do
    for declaration in declarations do
      checked := checked + 1
      let actual := sortNames (axiomsOfExactPoA env declaration)
      let want := sortNames expected
      unless actual == want do
        failures := failures.push
          s!"{label}: {declaration}\n  expected: {want.toList}\n  kernel:   {actual.toList}"
  unless failures.isEmpty do
    throwError "FUL-502 axiom-profile drift:\n{String.intercalate "\n" failures.toList}"
  logInfo s!"[check_exact_poa_axioms] {checked} declaration profiles match"

#assert_exact_poa_axiom_profiles

-- Canonical root and every theorem in its exact owner cone remain kernel-1.
#print axioms Fulcrum.GameTheory.constrained_poa_exact
#print axioms Fulcrum.GameTheory.exactAllModerate_isNash
#print axioms Fulcrum.GameTheory.exactNash_eq_allModerate
#print axioms Fulcrum.GameTheory.exactAllModerate_feasible
#print axioms Fulcrum.GameTheory.exactAllModerate_welfareNumerator
#print axioms Fulcrum.GameTheory.exactConstrained_welfare_optimal
#print axioms Fulcrum.GameTheory.exactConstrained_poa_one

-- Separately measured noncanonical compatibility/correspondence roots.
#print axioms Fulcrum.GameTheory.constrained_poa_exact_real_compat
#print axioms Fulcrum.GameTheory.exactPayoff_value
#print axioms Fulcrum.GameTheory.exactIsNash_iff_isNashEquilibrium
#print axioms Fulcrum.GameTheory.exactWelfare_value
#print axioms Fulcrum.GameTheory.exactFullClaim_iff_realFullClaim
#print axioms Fulcrum.GameTheory.exactCompleteDomain_iff_realCompleteDomain

