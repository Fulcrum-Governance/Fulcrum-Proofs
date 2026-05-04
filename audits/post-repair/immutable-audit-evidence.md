# Immutable Audit Evidence (`TST-AUDIT-003`)

## Objective
Show that benchmark and fault artifacts are persisted as immutable raw evidence with source commit linkage.

## Evidence
- Benchmark raw artifacts: `benchmarks/raw/`
- Fault raw artifacts: `fault/raw/`
- Each benchmark run includes:
  - `fulcrum_commit`
  - `contracts_snapshot_sha`
  - `data_source`
- Each fault run includes:
  - `fulcrum_commit`
  - `scenario_hash`
  - `data_source`
  - `evidence_class`

## Result
Pass: traceability fields are required by schema and verified by gate scripts.
