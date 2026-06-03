# Fulcrum-Proofs Phase 2 Authority Cleanup Spec

> **Status (2026-06-03): Applied and retained as provenance.** This handoff
> spec was executed through PR #21 (`36dc831`) and is no longer a live work
> plan. Current theorem/status authority remains the tracked claim ledgers,
> README/AGENTS wording, and the dated supersession banners referenced below.

**Handoff target:** Claude Code / Codex
**Date:** 2026-05-06
**Classification:** Documentation authority reconciliation — no Lean proof changes
**Branch:** `fix/proofs-phase2-authority-cleanup` (ALREADY CREATED from fresh `main` post-PR #20)
**Repo:** `/Users/td/ConceptDev/Projects/Fulcrum-Proofs`
**PR title:** `fix: Phase 2 authority cleanup — claim demotion, theorem metadata, audit supersession`
**Depends on:** PR #20 merged ✅

---

## CRITICAL: Branch Verification

This branch already exists. Verify before any work:

```bash
cd /Users/td/ConceptDev/Projects/Fulcrum-Proofs
git branch --show-current
# Must output: fix/proofs-phase2-authority-cleanup
git log --oneline -1
# Must show a commit from main (the PR #20 squash merge)
```

If you are NOT on this branch, `git checkout fix/proofs-phase2-authority-cleanup`. Do NOT create a new branch.

---

## Scope

7 documentation changes from the approved Phase 2 prioritization review. Zero Lean code changes. Zero proof changes. `lake build` is NOT required and should NOT be run.

Authority: `fulcrum-io/docs/repo-governance/2026-05-04-phase2-prioritization-review.md` — approved May 6.

---

## Task 1: Demote claim_closure.yaml [CRITICAL]

**File:** `claims/claim_closure.yaml`

This file contradicts the current theorem authority in multiple places. Per Phase 2 approval, it is demoted until reconciled. `theorem_inventory.yaml` is the theorem-level authority.

### 1a. Add demotion header

Insert at the top of the file, immediately after the existing `version` / `updated_at` / `description` block:

```yaml
authority_status: demoted
demotion_reason: >
  This file contains stale entries that contradict the current theorem state
  in claims/theorem_inventory.yaml (the theorem-level canonical source).
  Specifically: line 20 says "private" (repo is MIT public since ADR-001/002,
  May 3); lines 138-140 reference "proven-with-sorry" and Kakutani axiom
  (C-018 is sorry-free since April 27). This file remains for historical
  traceability but is NOT the authority for theorem status. Reconciliation
  is tracked as a Phase 2 follow-up.
demoted_at: 2026-05-06
superseded_by: claims/theorem_inventory.yaml
```

### 1b. Fix the "private" repo designation

**Line 20, find:**
```yaml
  Fulcrum-Proofs: formal core, claim ledger, benchmarks (private)
```

**Replace with:**
```yaml
  Fulcrum-Proofs: formal core, claim ledger, benchmarks (MIT)
```

### 1c. Do NOT rewrite the C-009 or C-018 entries

The stale "proven-with-sorry" language on lines 138-140 stays as-is. The demotion header makes it clear this file is not authoritative. Rewriting individual entries risks introducing new inconsistencies in a file that needs full reconciliation later.

**Validation:**
```bash
python3 -c "import yaml; yaml.safe_load(open('claims/claim_closure.yaml')); print('OK')"
grep 'authority_status: demoted' claims/claim_closure.yaml
```

**Commit:** `fix: demote claim_closure.yaml — stale entries contradict theorem_inventory`

---

## Task 2: Add THM-NASH-UNIQUENESS to theorem_inventory.yaml [IMPORTANT]

**File:** `claims/theorem_inventory.yaml`

The `nash_eq_allModerate` theorem in `NashUniqueness.lean` proves that the all-moderate profile is the unique Nash equilibrium under tight budget. It is referenced by multiple downstream theorems (PoA bound, constrained PoA) but has no dedicated entry in the inventory.

**Add after the THM-NASH-MIXED-EXISTENCE entry:**

```yaml
  - theorem_id: THM-NASH-UNIQUENESS
    assumptions:
      - A-GAME-001: agents have finite action sets (4 actions)
      - A-GAME-002: budget = 25 * agentCount (tight budget)
      - A-GAME-003: violation penalty (20) > quality gain from noncompliance (1)
      - A-GAME-006: agentCount in range 2..12
    lean_module: Proofs/GameTheory/NashUniqueness.lean
    dependencies: [THM-NASH-PURE-EXISTENCE, THM-NONCOMPLIANT-DOMINATED]
    proof_status: proven
    axiom_profile: [propext, Classical.choice, Quot.sound]
    sorry_count: 0
    notes: >
      Proves all Nash equilibria under tight budget are the all-moderate profile
      (nash_eq_allModerate). Used by fulcrum_poa_bounded and constrained_poa_exact
      to close the PoA bounds. Exhaustive for agentCount in 2..12; the bound is
      a parameter hypothesis, not a proof limitation.
```

**Verify the theorem exists:**
```bash
grep -n "theorem nash_eq_allModerate" proofs/lean/Proofs/GameTheory/NashUniqueness.lean
# Must return a line number
```

**Update the file timestamp:**
Change `updated_at:` to `2026-05-06`.

**Validation:**
```bash
python3 -c "import yaml; yaml.safe_load(open('claims/theorem_inventory.yaml')); print('OK')"
grep 'THM-NASH-UNIQUENESS' claims/theorem_inventory.yaml
```

**Commit:** `fix: add THM-NASH-UNIQUENESS to theorem inventory`

---

## Task 3: Propagate agentCount ≤ 12 on public theorem surfaces [IMPORTANT]

**File:** `README.md`

The game theory claims table in the README does not explicitly state the small-agent bound. This is documented in `HYPOTHESES.md` and the GameTheory README but should be visible on the main public surface.

**Find the C-018 row in the Claims table:**
```
| C-018 | Coordination game admits a Nash equilibrium | Proven (sorry-free; mixed Nash via Brouwer-via-Scarf, Kakutani axiom removed) |
```

**Replace with:**
```
| C-018 | Coordination game admits a Nash equilibrium | Proven (sorry-free; mixed Nash via Brouwer-via-Scarf for arbitrary finite games; pure-strategy uniqueness verified for agentCount ≤ 12) |
```

**Find the C-020 row:**
```
| C-020 | Constrained Price of Anarchy is 1.0 under tight budget | Proven (formal constrained PoA = 1.0; reference upper bound 9/7) |
```

**Replace with:**
```
| C-020 | Constrained Price of Anarchy is 1.0 under tight budget | Proven (formal constrained PoA = 1.0 for agentCount ≤ 12; unconstrained reference upper bound PoA ≤ 9/7) |
```

**Commit:** `docs: propagate agentCount ≤ 12 bound on public theorem surfaces`

---

## Task 4: Scope zero-sorry wording to first-party proofs [IMPORTANT]

**File:** `README.md`

**Find:**
```
### Remaining Sorry Holes (0 of 16 original)

All originally-tracked sorry holes are closed.
```

**Replace with:**
```
### Remaining Sorry Holes (0 of 16 original)

All originally-tracked sorry holes are closed. The zero-sorry claim covers all first-party Lean proofs in `Proofs/`. The vendored dependency (`vendor/Gametheory/`, MIT-licensed from math-xmum/Brouwer) is upstream code whose proof integrity is inherited, not re-verified by `check_no_sorry.sh`.
```

**Also in `AGENTS.md`, find:**
```
0 remaining sorry holes (down from 16).
```

**Replace with:**
```
0 remaining sorry holes across all first-party Lean proofs (down from 16).
```

**Commit:** `docs: scope zero-sorry wording to first-party Lean proofs`

---

## Task 5: Add supersession banners to historical audit files [IMPORTANT]

These files contain stale verdicts (C-005 as "Incomplete/waived") that are now resolved. Per Phase 2 approval, historical audits stay frozen and gain dated superseding banners rather than narrative rewrites.

### 5a. `audits/final/post-repair-re-audit.md`

**Insert at the very top of the file (before the `#` heading):**

```markdown
> **⚠️ SUPERSEDED (2026-05-06):** This audit was conducted before C-005 was proven
> (2026-04-02), before C-018 mixed Nash was closed sorry-free (2026-04-27), before
> C-020 constrained PoA was proved (2026-04-27), and before the Fulcrum-Proofs
> repository was relicensed to MIT (2026-05-03). The verdicts below reflect the
> proof state as of their original date. For current theorem status, see
> `claims/theorem_inventory.yaml`. For the resolution timeline, see
> `audits/final/addendum-2026-05-01.md`.

```

### 5b. `audits/final/independent-review.md`

**Insert at the very top of the file (before the `#` heading):**

```markdown
> **⚠️ SUPERSEDED (2026-05-06):** This review was conducted before C-005 was proven,
> before C-018/C-020 were closed sorry-free, and before the MIT relicense. The
> findings below reflect the proof state as of their original date. For current
> status, see `claims/theorem_inventory.yaml` and `audits/final/addendum-2026-05-01.md`.

```

### 5c. `audits/final/orchestrator-run-summary.md`

Check if this file also references stale C-005/C-018 status:
```bash
grep -n "waived\|incomplete\|proven-with-sorry" audits/final/orchestrator-run-summary.md
```

If it does, add the same supersession banner pattern. If it doesn't, skip.

**Commit:** `docs: add supersession banners to historical audit files`

---

## Task 6: Update GameTheory README with uniqueness and bounds [MINOR]

**File:** `proofs/lean/Proofs/GameTheory/README.md`

Check if the README already documents the `agentCount ≤ 12` bound and the uniqueness theorem. If not, add a row to the module table:

```
| `NashUniqueness.lean` | All Nash equilibria under tight budget are all-moderate (agentCount ≤ 12) |
```

And verify that the assumption register section includes `agentCount ≤ 12` as a listed hypothesis.

**Commit (if changed):** `docs: update GameTheory README with uniqueness bounds`

---

## Task 7: Update claim_scope.yaml with THM-NASH-UNIQUENESS reference [MINOR]

**File:** `claims/claim_scope.yaml`

The C-018 closure criteria should reference uniqueness. Add to the C-018 `closure_criteria` list:

```yaml
      - nash_uniqueness_proven_for_bounded_agent_count
```

**Validation:**
```bash
python3 -c "import yaml; yaml.safe_load(open('claims/claim_scope.yaml')); print('OK')"
```

**Commit:** `fix: add uniqueness criterion to C-018 closure criteria`

---

## Final Validation Sequence

```bash
cd /Users/td/ConceptDev/Projects/Fulcrum-Proofs

# 1. Confirm branch
git branch --show-current
# Must output: fix/proofs-phase2-authority-cleanup

# 2. YAML integrity
python3 -c "import yaml; yaml.safe_load(open('claims/claim_closure.yaml')); print('closure OK')"
python3 -c "import yaml; yaml.safe_load(open('claims/claim_scope.yaml')); print('scope OK')"
python3 -c "import yaml; yaml.safe_load(open('claims/theorem_inventory.yaml')); print('inventory OK')"

# 3. THM-NASH-UNIQUENESS exists
grep 'THM-NASH-UNIQUENESS' claims/theorem_inventory.yaml

# 4. Demotion header exists
grep 'authority_status: demoted' claims/claim_closure.yaml

# 5. Supersession banners exist
head -5 audits/final/post-repair-re-audit.md
head -5 audits/final/independent-review.md

# 6. No Lean files modified
git diff --name-only | grep '\.lean$' | head -5
# Must output nothing

# 7. No sorry regression
bash proofs/lean/scripts/check_no_sorry.sh
```

---

## Push and PR

```bash
git push origin fix/proofs-phase2-authority-cleanup
```

Create PR targeting `main` with:
- **Title:** `fix: Phase 2 authority cleanup — claim demotion, theorem metadata, audit supersession`
- **Body:** `Phase 2 documentation authority reconciliation per approved 2026-05-04-phase2-prioritization-review.md. Demotes claim_closure.yaml until reconciled, adds THM-NASH-UNIQUENESS to inventory, propagates agentCount ≤ 12 on public surfaces, scopes zero-sorry wording to first-party proofs, and adds supersession banners to historical audits. No Lean proof changes.`
- **Labels:** `documentation`, `chore`

---

## What NOT To Do

- Do NOT run `lake build`
- Do NOT modify any `.lean` file
- Do NOT rewrite the stale entries inside `claim_closure.yaml` — the demotion header handles it
- Do NOT edit `claim_ledger.yaml` — it was reconciled in Wave 1 and is current
- Do NOT edit the addendum file (`addendum-2026-05-01.md`) — it's already correct
- Do NOT touch the `proofs/lean/vendor/` directory
- Do NOT merge the PR — leave for manual review
