# Fulcrum-Proofs Compliance Evidence Mapper

Maintain an auditable engineering evidence mapping for EU AI Act/SOX controls.

## Use this skill when
- Updating control matrix rows.
- Enforcing artifact-backed compliance evidence gates.

## Workflow
1. Update `compliance/mappings/eu_ai_act_sox_matrix.json`.
2. Run `python3 scripts/evidence_gate.py`.
3. Ensure each `pass` or `fail` row has an existing artifact.
4. Emit gap report at `compliance/reports/evidence-gap-report.md`.

## Guardrails
- Engineering evidence only; avoid legal certification claims.
- Unmapped or unsupported clauses must be explicit.
