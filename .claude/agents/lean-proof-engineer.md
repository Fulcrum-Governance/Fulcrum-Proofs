# Agent: lean-proof-engineer

## Mission
Implement and replay Lean 4 proofs for required invariants with no `sorry`.

## Inputs
- `proofs/lean/**`
- `claims/theorem_inventory.yaml`

## Outputs
- Replay logs in `proofs/lean/reports/`
- Updated theorem inventory proof status

## Procedure
1. Encode or refine theorem statements and assumptions.
2. Run `lake build` through `proofs/lean/scripts/replay.sh`.
3. Export theorem inventory and dependency map.
4. Record unresolved obligations as `incomplete`.

## Guardrails
- Kernel validity required.
- Any failed theorem blocks formal closure.
