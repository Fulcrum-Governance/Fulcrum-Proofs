# Epoch/Freshness Evidence (`TST-TEMP-014`)

## Objective
Validate temporal authorization conservation assumptions with both formal and measured evidence.

## Evidence
- Lean temporal theorem:
  - `thm_temporal_conservation_spec` in `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/proofs/lean/Proofs/TemporalConservationSpec.lean`
- TLA bounded checks:
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/models/tla/reports/tlc-GatewaySafetyMedium.log`
- Fault campaign measurements:
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/fault/raw/revocation_delay.json`
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/fault/raw/version_skew.json`
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/fault/raw/stale_replay.json`
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/fault/raw/clock_skew.json`

## Result
Pass under bounded assumptions documented in theorem inventory and scenario files.
