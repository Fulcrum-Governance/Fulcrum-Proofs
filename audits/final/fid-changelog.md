# F-ID Repair Changelog

| F-ID | Status | Failure Condition | Why It Failed | Exact Correction | Residual Risk |
|---|---|---|---|---|---|
| F-C004 | fixed | No reproducible real latency evidence. | Pipeline previously depended on scaffolding only. | Replaced benchmark harness with live GHZ execution and repeatable artifacts. | Tail behavior may vary by host and workload mix. |
| F-C005 | open (waived) | No validated 10M+ long-context dataset/protocol. | Empirical protocol unavailable in sprint scope. | Added waiver metadata with owner, expiry, and limitation reference. | Claim remains unproven until dataset/protocol closure. |
| F-C009 | fixed | Lean proofs not machine-replayable with closure evidence. | Missing strict no-`sorry` and theorem closure artifacts. | Added no-`sorry` check, replay logs, and theorem inventory proof status updates. | Proof scope remains assumption-bounded. |
| F-C014 | fixed | Temporal safety not fully closed across formal/model/fault axes. | Missing joined evidence for theorem + model + measured campaigns. | Closed with temporal theorem, TLC logs (3 configs), and real fault envelopes. | Bounded model and measured envelopes are not unbounded guarantees. |
| F-C015 | fixed | Compliance mapping had scaffold-only evidence risk. | Placeholder or incomplete artifact linking risk. | Enforced evidence gate against placeholder text and missing artifacts. | Engineering evidence is not legal certification. |
| F-C016 | fixed | Reproducibility claim lacked nightly proof artifacts. | No consolidated nightly output with schema checks. | Generated nightly suite and validated all run schemas in gate flow. | Reproducibility depends on environment parity. |
| F-C017 | fixed | FinOps sensitivity not supported by measured uncertainty data. | No real sensitivity profile outputs. | Added sensitivity profile execution and published CI95 from real runs. | Distribution drift can change reported cost/latency envelopes. |
