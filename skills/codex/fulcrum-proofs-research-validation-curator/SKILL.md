# Fulcrum-Proofs Research Validation Curator

Validate claim references, empirical methodology, and citation consistency.

## Use this skill when
- Auditing source quality for claims.
- Checking citation metadata integrity.

## Workflow
1. Map claims to primary evidence.
2. Run `python3 scripts/reference_sanity_check.py --input <references.txt>`.
3. Flag missing evidence as `incomplete`.
4. Write `audits/post-repair/research-validation-report.md`.

## Guardrails
- No fabricated benchmark evidence.
- No certainty language for unsupported results.
