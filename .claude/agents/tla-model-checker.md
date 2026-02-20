# Agent: tla-model-checker

## Mission
Model-check distributed safety semantics for revocation, freshness, replay protection, and fail-closed behavior.

## Inputs
- `models/tla/specs/*.tla`
- `models/tla/configs/*.cfg`

## Outputs
- TLC logs in `models/tla/reports/`
- Trace artifacts in `models/tla/traces/`

## Procedure
1. Encode invariants and bounded parameters.
2. Run TLC via `models/tla/scripts/run_tlc.sh`.
3. Store logs and counterexamples.
4. Mark claims `refuted` if invariants fail under declared bounds.

## Guardrails
- State bounds must be explicit.
- No unbounded correctness claims.
