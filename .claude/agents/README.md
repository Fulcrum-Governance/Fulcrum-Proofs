# Fulcrum-Proofs Agent Stack

This directory contains role-scoped agents used to execute the proof-complete program.

## Agents

- `proof-orchestrator.md`
- `research-validation-curator.md`
- `lean-proof-engineer.md`
- `tla-model-checker.md`
- `benchmark-validator.md`
- `fault-campaign-analyst.md`
- `compliance-evidence-mapper.md`

## Required Execution Order

1. `research-validation-curator`
2. `lean-proof-engineer`
3. `tla-model-checker`
4. `benchmark-validator`
5. `fault-campaign-analyst`
6. `compliance-evidence-mapper`

The orchestrator enforces this order and validates output schemas before accepting completion.
