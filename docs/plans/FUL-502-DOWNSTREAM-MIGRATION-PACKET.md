# FUL-502 Downstream Citation Migration Packet

**Status:** FOUNDER HOLD — inventory only. Do not execute cross-repository
edits from this Proofs lane. Launch separate repository lanes only after the
FUL-502 Proofs PR merges and the founder authorizes migration.

## Source locks revalidated at Gate 0

| Repository | Revalidated `origin/main` SHA |
|---|---|
| `fulcrum-io` | `053b92f95c01ffde2c4bfc5bbdead080de9f1dbe` |
| `Fulcrum-Boundary` | `87ddf3d484af17880714f19260d737318edaa13d` |
| `Fulcrum-Papers` | `fc3a0380f670dd0e14144ca8b813c8586d414d20` |

These locks establish the inventory snapshot only. Every downstream lane must
fetch and revalidate its own live base, overlap, and active claim surface.

## Required downstream wording

- Canonical theorem: `constrained_poa_exact` in
  `CoordinationEfficiencyExact.lean`, a complete six-clause exact-data claim at
  exactly `[propext]`.
- Formal domain: every positive agent count `1..12`. Positivity is the existing
  `BudgetParams` invariant; there is no `2 ≤ agentCount` hypothesis.
- Empirical domain: the existing exhaustive count-equivalence artifact remains
  `2..12`. It is corroboration, not the formal theorem domain.
- Real compatibility: `constrained_poa_exact_real_compat`, noncanonical
  compatibility/provenance evidence at
  `[propext, Classical.choice, Quot.sound]`.
- Integer companion: `constrained_poa_exact_int`, additive welfare-only evidence
  at `[propext, Quot.sound]`; it has no Nash quantifier.
- Do not claim a structural theorem for `n ≥ 13`, a runtime refinement theorem,
  a broader budget regime, or a public D4 v3 publication.

## Fulcrum active citations

Migrate in one future `fulcrum-io` lane after merge:

- `conductor/tracks/program-2026h2/w3-deck-skeleton.md` — PoA proof citation
  near line 147.
- `conductor/tracks/program-2026h2/w5-proof-premium-note.md` — proof/profile
  discussion near lines 145–167 and 383.
- `docs/formal-verification/CORRESPONDENCE.md` — theorem and axiom-profile map
  near lines 85–102.
- `dashboard/src/data/proofs-status.snapshot.json` — active proof status object
  near lines 374–392.
- `conductor/tracks/program-2026h2/w3-evidence-spine.md` — constrained PoA
  evidence rows near lines 36 and 40.
- `claims/fulcrum_claims.yaml` — direct theorem citation near line 595.
- `docs/validation/claims-lock.md` — direct constrained-PoA claim near line 228.
- Active threshold specifications, program plan/W2/W3 records, and current
  Superpowers plans/specifications returned by a live search for
  `constrained_poa_exact`, `THM-POA-CONSTRAINED`, `PoA = 1`, and domain wording.
- `.claude/PROJECT_INSTRUCTIONS.md` — active PoA/profile/domain wording near
  lines 70, 121, 138, 168, 183, and 359.
- `.claude/sprint/strategy/2026-07-vision-2027/EVIDENCE_LEDGER.md` — active
  Nash/PoA evidence wording near line 60.
- `_ASSET_MAP.md` — active exhaustive-enumeration wording near line 145.

The last three semantic consumers were outside the earlier exact-symbol list.
They must distinguish formal `1..12` from empirical `2..12` rather than
rewriting the empirical artifact's true range.

## Fulcrum-Boundary active citations

Migrate in a separate Boundary lane after merge:

- `docs/PROOF_BOUNDARY.md` — constrained PoA/theorem boundary wording near line
  21.
- Re-run an active-corpus search for `constrained_poa_exact`,
  `THM-POA-CONSTRAINED`, `PoA`, `2..12`, and `agentCount ≤ 12` before editing.

Boundary wording must remain a citation boundary. FUL-502 proves mathematical
representation correspondence, not runtime protocol or enforcement refinement.

## Fulcrum-Papers active citations

Migrate only in a separately authorized Papers lane after merge:

- `d3/v7-ghost/D3_v7.md` — constrained-PoA discussion near lines 200–202.
- `d3/v8/D3_v8.md` — theorem/evidence discussion near lines 372–385.
- `d4/source/D4-paper.tex` — constrained theorem, assumptions, and evidence
  references near lines 470–525, 818–841, and 908.
- Active D4 specifications and advancement plans returned by direct searches
  for the theorem name, theorem ID, axiom profile, `2..12`, and PoA wording.
- `specs/D3_D4_EVALUATION_REPORT.md` — evaluation summary near lines 124–125.

## Frozen provenance — do not edit

- Published D4 v2 artifacts, released builds, uploaded archives, DOI records,
  checksums, public claims locks, and historical evidence snapshots.
- Historical drafts whose purpose is to preserve what was asserted at their
  recorded date.
- `evidence/constrained_poa_results.json`: its empirical enumeration really is
  `2..12` and must not be relabeled `1..12`.

If an active document quotes a frozen artifact, add current migration context
around the citation; do not rewrite the frozen source.

## Proofs declaration map for downstream citations

| Obligation | Named declarations |
|---|---|
| 1. action data | `exactActionCost_eq_actionTokenCost`, `exactActionQuality_eq_actionQuality`, `exactActionViolates_eq_actionViolates`, `exactViolationPenalty_eq_violationPenalty`, `exactActionPenalty_eq_legacyPenalty` |
| 2. roster/index coverage | `correspondenceRoster_length`, `correspondenceRoster_get` |
| 3. token total | `structuralSum_eq_finsetSum`, `exactTotalTokens_eq_totalTokens` |
| 4. signed interpretation/order | `signedNatValue_add`, `signedNat_le_iff_real_le` |
| 5. payoff values | `exactPayoff_value`, `exactPayoff_value_noOverflow`, `exactPayoff_value_overflow` |
| 6. payoff order | `exactPayoff_le_iff_realPayoff_le` |
| 7. unilateral update | `exactUpdate_eq_functionUpdate`, `correspondenceUpdate_changed`, `correspondenceUpdate_unchanged` |
| 8. feasibility | `exactWithinBudget_iff_withinBudget` |
| 9. Nash predicate | `exactIsNash_iff_isNashEquilibrium` |
| 10. welfare value/order | `structuralSignedSum_value`, `exactWelfare_value`, `exactWelfare_le_iff_realWelfare_le` |
| 11. all-moderate identities | `exactAllModerate_profile`, `exactAllModerate_cost`, `exactAllModerate_feasibility_iff`, `exactAllModerate_feasibility`, `exactAllModerate_payoff`, `exactAllModerate_welfare` |
| 12. existence/uniqueness | `exactAllModerate_nash_iff_real`, `exactNashUniqueness_iff_real`, `exactAllModerate_existence_and_uniqueness` |
| 13. complete compound claim | `realFullClaim`, `exactFullClaim_iff_realFullClaim` |
| 14. complete domain | `ExactCompleteDomain`, `RealCompleteDomain`, `exactCompleteDomain_iff_realCompleteDomain` |

## Exit condition for each future lane

Bind all citation updates to the merged Proofs SHA, preserve the distinctions
above, run that repository's required gates, and hand back for founder review.
No lane may infer permission for Papers publication, DOI/upload work, claims-lock
changes, or the `n ≥ 13` threshold theorem.
