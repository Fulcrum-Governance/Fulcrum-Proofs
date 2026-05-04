# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Public-flip readiness docs, integrity probes, and reproducibility gates for the
  Lean/TLA+/evidence stack.

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

[0.1.0]: https://github.com/Fulcrum-Governance/Fulcrum-Proofs/releases/tag/v0.1.0
