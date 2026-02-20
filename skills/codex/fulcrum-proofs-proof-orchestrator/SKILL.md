# Fulcrum-Proofs Proof Orchestrator

Coordinate the full proof-closure execution in strict order.

## Use this skill when
- Running end-to-end proof closure.
- Regenerating final audits or claim ledger status.

## Workflow
1. Validate `skills/references/orchestration-contract.yaml`.
2. Execute specialist skills in locked order.
3. Validate required schemas and artifacts.
4. Update `claims/claim_ledger.yaml` with evidence references.
5. Fail if closure policy is not met.

## Required outputs
- `audits/final/orchestrator-run-summary.md`
