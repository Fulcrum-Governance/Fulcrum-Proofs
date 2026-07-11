import Lean

/-!
NON-SHIPPING FIXTURE — expected to FAIL.

This file constructs a theorem whose proof term is `sorryAx` applied
directly, without the `sorry` token ever appearing, so the source grep
gate (`scripts/check_no_sorry.sh`) cannot see it. The kernel-level probe
must. `scripts/probe_gate.sh` runs this file and REQUIRES a non-zero
exit: if this file ever elaborates successfully, the sorryAx detection
mechanism is broken and the gate fails.

The file is intentionally self-contained (no Proofs import) and is not
part of any build target.
-/

open Lean Elab Command

theorem fixture_implicit_placeholder : (1 : Nat) + 1 = 2 := sorryAx _ false

def fixtureAxiomsOf (env : Environment) (constName : Name) : Array Name :=
  ((CollectAxioms.collect constName) env |>.run {}).2.axioms

elab "#assert_fixture_clean" : command => do
  let env ← getEnv
  if (fixtureAxiomsOf env ``fixture_implicit_placeholder).contains ``sorryAx then
    throwError "sorryAx detected in fixture (expected: the gate must bite here)"
  logInfo "fixture unexpectedly clean — sorryAx detection is BROKEN"

#assert_fixture_clean
