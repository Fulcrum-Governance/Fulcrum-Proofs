# Epoch/Freshness Evidence (`TST-TEMP-014`)

## Objective
Validate temporal authorization conservation assumptions with both formal and measured evidence.

## Evidence
- Lean temporal theorem:
  - `thm_temporal_conservation_spec` in `proofs/lean/Proofs/TemporalConservationSpec.lean`
- TLA bounded checks:
  - `models/tla/reports/tlc-GatewaySafetyMedium.log`
- Fault campaign measurements:
  - `fault/raw/revocation_delay.json`
  - `fault/raw/version_skew.json`
  - `fault/raw/stale_replay.json`
  - `fault/raw/clock_skew.json`

## Result
Pass under bounded assumptions documented in theorem inventory and scenario files.
