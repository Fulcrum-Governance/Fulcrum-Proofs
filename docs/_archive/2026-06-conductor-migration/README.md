# Archive — 2026-06 Conductor migration

Frozen provenance for two **already-applied** handoff specs, moved here from
`.claude/` during the June 2026 Conductor workspace migration. They are retained
for traceability only and are **not** live work plans. The authoritative record
of what they changed is the merged PRs they cite and later mainline commits.

| Spec | Date | Applied via | Status |
|------|------|-------------|--------|
| `PROOFS-REPO-AUDIT-FIX-SPEC.md` | 2026-05-06 | PR #20 (`7b755d4`) | Applied — DOI/CITATION, git hygiene, proof-gate `replay.sh` hardening, session-log move |
| `PROOFS-PHASE2-AUTHORITY-CLEANUP-SPEC.md` | 2026-05-06 | PR #21 (`36dc831`) | Applied — claim demotion, `THM-NASH-UNIQUENESS` inventory entry, audit supersession banners, scoped zero-sorry wording |

## Lifted follow-up

`PROOFS-PHASE2-AUTHORITY-CLEANUP-SPEC.md` Task 1c intentionally **deferred** the
per-entry reconciliation of `claims/claim_closure.yaml`, leaving the stale
C-009 "proven-with-sorry / Kakutani-axiom dependency gap" note under the demotion
header and tracking it as a Phase 2 follow-up. That follow-up was completed on
2026-06-22 (same change set that created this archive):

- C-009 now reflects `THM-NASH-MIXED-EXISTENCE` as sorry-free with the
  `kakutani_fixed_point_theorem` axiom removed, and enumerates all 21 canonical
  theorem IDs (added `THM-NASH-UNIQUENESS`, `THM-POA-CONSTRAINED`).
- `claim_closure.yaml` `authority_status` moved `demoted` → `reconciled`.

With that, no live work remains from either spec.

## Canonical sources (unchanged)

- `claims/theorem_inventory.yaml` — canonical theorem status (proof state, axiom profile).
- `claims/claim_scope.yaml` — claim statements and closure criteria.
- `claims/claim_ledger.yaml` — claim → evidence history.

`claims/claim_closure.yaml` is a derived closure manifest, now consistent with the above.
