# Claim Ledger Delta (Pre vs Post)

Baseline snapshot date: 2026-02-20 (pre-closure ledger in this sprint).

| Claim ID | Pre Status | Post Status | Delta Reason |
|---|---|---|---|
| C-004 | incomplete | proven | Real benchmark runs + schema-validated artifacts + nightly suite. |
| C-005 | incomplete | incomplete (waived) | Deferred by explicit waiver (`claims/waivers.yaml`). |
| C-009 | incomplete | proven | Lean replay passed; theorem inventory updated to proven. |
| C-014 | incomplete | proven | Temporal theorem, TLC logs, and measured fault bounds all present. |
| C-015 | incomplete | proven | Compliance matrix mapped to concrete evidence artifacts. |
| C-016 | incomplete | proven | Reproducible benchmark harness and nightly output validated. |
| C-017 | incomplete | proven | FinOps sensitivity data and CI95 outputs generated from real mode. |

Summary:
- Proven moved from 0 to 6.
- Incomplete remained 1 (`C-005`, waived).
- Refuted remained 0.
