# Gate Fail-Closed Evidence (`TST-GATE-001`)

## Objective
Verify the gateway safety model denies authorization when freshness, nonce, replay, or revocation conditions fail.

## Evidence
- TLA model:
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/models/tla/specs/GatewaySafety.tla`
- TLC reports:
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/models/tla/reports/tlc-GatewaySafetySmall.log`
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/models/tla/reports/tlc-GatewaySafety.log`
  - `/Users/td/ConceptDev/Projects/Fulcrum-Proofs/models/tla/reports/tlc-GatewaySafetyMedium.log`
- Invariants checked:
  - `FailClosedOnInvalidContext`
  - `ReplayDenied`
  - `RevocationFailClosed`
  - `FreshnessRequired`
  - `NonceRequired`

## Result
Pass: all configured model bounds checked without invariant violation.
