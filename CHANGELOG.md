# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-08-15

### Added
- A Real-typed threshold theorem proving only that the all-moderate profile
  ceases to be Nash for `agentCount ≥ 13` under the tight budget relation,
  witnessed by a strictly profitable aggressive unilateral deviation.
- Exact signed-Nat coordination-game owner modules with structural roster,
  sum/update, Nash existence/uniqueness, feasibility, exact welfare, and
  relational PoA proofs for every positive agent count `1..12`.
- Fourteen named machine-checked exact/Real correspondence obligation families,
  kept downstream of the canonical dependency cone and separately profiled.
- A fail-closed FUL-502 probe asserting 100 canonical, compatibility, and
  correspondence declaration profiles.

### Changed
- Migrated canonical `constrained_poa_exact` to the complete six-clause
  exact-data claim at exactly `[propext]`: Nash existence, pointwise uniqueness,
  feasibility, exact `7*n` attainment, feasible welfare optimality, and every
  Nash/feasible relational comparison at PoA one.
- Renamed the previous Real theorem to
  `constrained_poa_exact_real_compat` and retained it as noncanonical
  compatibility/provenance evidence at kernel-3.
- Clarified that `constrained_poa_exact_int` is an additive welfare-only
  companion with no Nash quantifier, and separated the formal `1..12` domain
  from the existing empirical `2..12` enumeration.

## [0.2.0] - 2026-07-11

### Added
- `GovernedKernel.lean` and `KernelVariants.lean` ported byte-faithfully from the
  published D4 Zenodo supplement (DOI 10.5281/zenodo.19900714) — the public repo
  is now a superset of the published proof surface (deltas: import paths +
  provenance headers).
- `applyGuardedResource`/`guarded_monotone_resource` block in
  `BasicInvariants.lean`, from the published supplement.
- `CoordinationEfficiencyInt.lean`: integer-audit companion for the constrained
  welfare/PoA core (List/Int, structural recursion; measured axiom profile
  `[propext, Quot.sound]`, Classical.choice-free).
- Kernel-level sorryAx probe that auto-enumerates all `Fulcrum.*` declarations,
  a grep-invisible expected-failure fixture proving the gate bites, and
  `check_central_axioms.lean` assertion mode — wired into `proof-gate.yml` as a
  required probe-gate step.
- Claims inventory entries with kernel-measured axiom profiles (C-024, C-025;
  C-020 strengthened).
- Public-flip readiness docs, integrity probes, and reproducibility gates for the
  Lean/TLA+/evidence stack.

### Changed
- Isolation axioms relabeled as tiered deployment assumptions quoting the
  published paper's own language; `ValidTransition` now documents the deployed
  recovery regimes (direct recovery by default; cooldown-gated
  OPEN→HALF_OPEN→CLOSED probe when configured — fulcrum-trust #28).
- C-005 (long-context governance accuracy) flipped `proven → tested` per the
  lapsed waiver (CL5-010 / ADR-032).
- `lake build` gate step made non-vacuous (three-layer guard); CI had been
  passing with 0 jobs built.
- `CITATION.cff` version reconciled to the tagged release series (was an
  untagged `1.0.0`).

## [0.1.0] - 2026-05-03

### Added
- `proofs/reproduce.sh` one-shot verification entrypoint covering `lake build`,
  zero-`sorry` drift detection, and axiom-profile baseline checks.
- `proofs/lean/probes/check_central_axioms.lean` plus
  `proofs/lean/expected_axioms.md` to document and validate the current
  theorem-by-theorem axiom surface.
- `CITATION.cff` for repository citation metadata.
- `HYPOTHESES.md` describing the non-axiom assumptions behind the main theorem
  families.
- README badges for proof gate, Lean, mathlib pin, license, sorry count, and DOI
  status.
- `claims/theorem_inventory.yaml` `axiom_profile` metadata for all tracked
  theorems.
- Portable contract-sync and evidence harness paths so fresh clones do not depend
  on a specific workstation layout.

### Changed
- Refreshed the final audit addendum to reflect the vendored `Gametheory`
  dependency and self-contained `lake build` flow.
- Removed tracked workstation-path leaks from public-facing files and scripts.

[0.2.0]: https://github.com/Fulcrum-Governance/Fulcrum-Proofs/releases/tag/v0.2.0
[0.1.0]: https://github.com/Fulcrum-Governance/Fulcrum-Proofs/releases/tag/v0.1.0
