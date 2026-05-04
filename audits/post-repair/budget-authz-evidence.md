# Budget + Authorization Evidence (`TST-BUDGET-010`)

## Objective
Demonstrate machine-checkable proof coverage for local budget safety and static privilege conservation.

## Evidence
- Lean proofs:
  - `proofs/lean/Proofs/BasicInvariants.lean`
  - `proofs/lean/Proofs/TemporalConservationSpec.lean`
- Replay artifacts:
  - `proofs/lean/reports/lake-build.log`
  - `proofs/lean/reports/theorem-inventory.txt`
  - `proofs/lean/reports/no-sorry-check.log`

## Result
Pass: replay compiles and required theorem IDs are present without `sorry`.
