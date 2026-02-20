# Fulcrum-Proofs Lean Proof Engineer

Implement and replay Lean 4 theorem closure for core invariants.

## Use this skill when
- Advancing formal claim closure.
- Investigating Lean replay failures.

## Workflow
1. Edit `proofs/lean/Proofs/*.lean`.
2. Run `./proofs/lean/scripts/replay.sh`.
3. Ensure no `sorry` and passing `lake build`.
4. Update `claims/theorem_inventory.yaml`.

## Required artifacts
- `proofs/lean/reports/lake-build.log`
- `proofs/lean/reports/theorem-inventory.txt`
