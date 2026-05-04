# Security Policy

## Scope

`Fulcrum-Proofs` is the formal-verification and evidence repository for the
Fulcrum governance kernel. Its main security-sensitive surfaces are proof
soundness, reproducibility gates, vendored dependency provenance, and audit
artifacts that may be consumed by downstream operators.

## Supported Versions

We currently support security and proof-soundness fixes for the latest `main`
branch and the most recent tagged release.

## Reporting A Vulnerability

Please do not report security or proof-soundness concerns in public GitHub
issues.

Send reports to `security@fulcrumlayer.io` and include:

- affected commit, branch, or release tag
- theorem, script, or workflow involved
- reproduction steps
- observed vs expected behavior
- any `bash proofs/reproduce.sh` output or `#print axioms` output that helps
  isolate the issue

## What To Report

- proof-soundness regressions
- unexpected axiom drift
- vendored dependency provenance or license problems
- CI gate bypasses that could mask invalid proof or evidence state
- sensitive data exposure in tracked evidence or audit files

## Known Boundaries

- `RLMContracts.lean` intentionally contains documented deployment axioms for
  sandbox-enforced isolation properties. Those axioms are tracked in the
  theorem inventory and the axiom-profile probe.
- Benchmark, fault, and compliance artifacts are evidence, not production
  runtime controls. Findings there should still be reported if they affect the
  accuracy of a public claim.

## Disclosure Policy

We follow coordinated disclosure with a default 90-day window.

- Please keep reports private while we investigate and prepare a fix.
- We will acknowledge receipt as quickly as possible and coordinate on
  disclosure timing.
- If remediation needs more time, we may request an extension by mutual
  agreement.
- If no extension is agreed, we expect public disclosure no later than 90 days
  after initial report receipt.
