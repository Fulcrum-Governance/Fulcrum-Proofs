# Decisions — where they live

**Cross-repo architecture and strategy decisions for the Fulcrum four-repo
system live in one canonical series: fulcrum-io
[`.claude/decisions/`](https://github.com/Fulcrum-Governance/Fulcrum-IO/tree/main/.claude/decisions)
— see its `INDEX.md` for the full numbered table (ADR-001…).** This repo hosts
no decision records and should stay that way.

## Freeze rule (FUL-353, program parent FUL-266)

- Do **not** create ADR files or a decisions directory in this repo. Decision
  records that primarily concern Fulcrum-Proofs (proof scope, toolchain,
  claim-ledger policy) land in the fulcrum-io canonical series and reference
  this repo from there.
- Proof/claim governance artifacts that already live here (`claims/`,
  `audits/`, `CHANGELOG.md`) are evidence and inventory, not decision records —
  they stay, and they are not a decisions surface.

## Why

The 2026-05-17 consolidation established a single numbered series so that
"why did you decide X" has exactly one answer path. Per-repo ADR dirs drifted,
renumbered, and contradicted each other; the canonical series plus this freeze
note is the repair. Numbering authority is the fulcrum-io filesystem
(`ls .claude/decisions/ADR-*.md | sort | tail -1`) — never quoted from prose.
