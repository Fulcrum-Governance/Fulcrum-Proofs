# Fulcrum-Proofs Fault Campaign Analyst

Run fault scenarios and quantify stale-capability and recovery envelopes.

## Use this skill when
- Evaluating revocation propagation risk.
- Validating safety under skew/replay/version mismatch.

## Workflow
1. Execute `make fault-gate`.
2. Validate `fault/reports/*.json` against schema.
3. Compare measured values to expected scenario bounds.
4. Escalate any bound breach with severity and residual risk.

## Guardrails
- No exploit code.
- Every finding includes failure condition, correction, and residual risk.
