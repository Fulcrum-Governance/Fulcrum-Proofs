# Fulcrum-Proofs TLA Model Checker

Model-check distributed authorization invariants under bounded fault assumptions.

## Use this skill when
- Validating revocation/freshness/replay behavior.
- Rechecking fail-closed semantics under partition or skew.

## Workflow
1. Edit `models/tla/specs/*.tla` and configs.
2. Run `./models/tla/scripts/run_tlc.sh`.
3. Review logs/counterexamples in `models/tla/reports/`.
4. Record bounded assumptions in findings.

## Guardrails
- Explicit model bounds required.
- Counterexample implies claim downgrade or refutation.
