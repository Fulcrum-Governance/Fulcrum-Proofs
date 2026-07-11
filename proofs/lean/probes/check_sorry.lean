import Lean
import Proofs

/-!
Kernel-level sorry probe.

`scripts/check_no_sorry.sh` greps sources for the `sorry` token. That check
cannot see `sorryAx` reaching a proof term through a macro expansion or a
tactic-inserted term (the DeepSeek-Prover-V2 / PutnamBench incident class:
proofs that read clean but depend on `sorryAx` at the kernel level).

This probe asks the kernel instead: it enumerates every declaration under
the `Fulcrum` namespace in the built environment and fails compilation if
`sorryAx` appears in any declaration's transitive axiom set. Enumeration is
automatic, so newly added theorems are covered without editing this file,
and vendored dependencies are covered transitively wherever a Fulcrum
declaration depends on them.

Companion: `probes/check_central_axioms.lean` (exact axiom profiles vs
`claims/theorem_inventory.yaml`). The fixture proving this probe bites is
`probes/fixtures/implicit_sorry_fixture.lean`, run by
`scripts/probe_gate.sh` with an expected-failure contract.
-/

open Lean Elab Command

/-- Transitive axiom set of `constName`, same traversal as `#print axioms`. -/
def axiomsOf (env : Environment) (constName : Name) : Array Name :=
  ((CollectAxioms.collect constName) env |>.run {}).2.axioms

/-- Union of axiom sets over `roots`, sharing one visited set (fast path). -/
def axiomsOfAll (env : Environment) (roots : Array Name) : Array Name :=
  let s : CollectAxioms.State := roots.foldl (init := {}) fun s n =>
    ((CollectAxioms.collect n) env |>.run s).2
  s.axioms

elab "#assert_fulcrum_sorry_free" : command => do
  let env ← getEnv
  let mut roots : Array Name := #[]
  for (n, _) in env.constants.toList do
    if (`Fulcrum).isPrefixOf n then
      roots := roots.push n
  if roots.isEmpty then
    throwError "probe found no Fulcrum declarations — wrong environment?"
  -- Fast path: one shared traversal over every root.
  if (axiomsOfAll env roots).contains ``sorryAx then
    -- Slow path only on failure: attribute the infection per declaration.
    let mut infected : Array Name := #[]
    for n in roots do
      if (axiomsOf env n).contains ``sorryAx then
        infected := infected.push n
    throwError "sorryAx reachable from {infected.size} declaration(s): {infected.toList}"
  logInfo s!"[check_sorry] {roots.size} Fulcrum declarations checked: no sorryAx"

#assert_fulcrum_sorry_free
