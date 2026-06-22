# Fulcrum-Proofs Repo Audit Fix Spec

> **Status (2026-06-03): Applied and retained as provenance.** This handoff
> spec was executed through PR #20 (`7b755d4`) and is no longer a live work
> plan. Current repo-hygiene authority remains the tracked files changed by
> that PR and later mainline commits.

**Handoff target:** Claude Code
**Date:** 2026-05-06
**Classification:** Hygiene — no proof logic changes
**Branch:** `fix/proofs-repo-audit-2026-05-06` (CREATE NEW from `main`)
**Repo:** `/Users/td/ConceptDev/Projects/Fulcrum-Proofs`
**PR title:** `chore: repo audit fixes — DOI, git hygiene, gate hardening`

---

## CRITICAL: Branch Isolation

**Before any work, execute these commands exactly:**

```bash
cd /Users/td/ConceptDev/Projects/Fulcrum-Proofs
git checkout main
git pull origin main
git checkout -b fix/proofs-repo-audit-2026-05-06
```

**If the branch already exists, STOP and ask.** Do not reuse branches. Do not work on `main` directly. Do not switch to any other branch for any reason during this task.

**Verify you are on the correct branch before every commit:**
```bash
git branch --show-current
# Must output: fix/proofs-repo-audit-2026-05-06
```

---

## Scope

8 fixes from a strategic audit. Zero proof changes. Zero Lean code changes. This is metadata, git hygiene, and CI gate hardening only. `lake build` is NOT required and should NOT be run (it takes 20+ minutes and nothing in this spec touches `.lean` files in a way that affects compilation).

---

## Task 1: Update CITATION.cff with Zenodo DOI [CRITICAL]

**File:** `CITATION.cff`

The D4 paper was published on Zenodo on April 30, 2026. The CITATION.cff still says "DOI pending."

**Changes:**

1. Add DOI fields to the top-level metadata:
```yaml
doi: "10.5281/zenodo.19900712"
identifiers:
  - type: doi
    value: "10.5281/zenodo.19900714"
    description: "This version"
  - type: doi
    value: "10.5281/zenodo.19900712"
    description: "All versions"
```

2. Update the `preferred-citation` section:
```yaml
preferred-citation:
  type: article
  title: "A Bounded, Machine-Checkable Governance Kernel for Trust-Gated Agent Execution"
  authors:
    - family-names: Diefenbach
      given-names: Anthony
      affiliation: "Independent Researcher"
  year: 2026
  doi: "10.5281/zenodo.19900714"
  url: "https://doi.org/10.5281/zenodo.19900714"
  publisher: "Zenodo"
  license: "CC-BY-4.0"
```

3. Update `version` from `"0.1.0"` to `"1.0.0"` (this is the public release version).

**Validation:**
```bash
# YAML syntax check
python3 -c "import yaml; yaml.safe_load(open('CITATION.cff')); print('CITATION.cff OK')"
```

**Commit:** `fix: update CITATION.cff with Zenodo DOI 10.5281/zenodo.19900714`

---

## Task 2: Update README DOI Badge [CRITICAL]

**File:** `README.md`

**Find this exact string:**
```
[![DOI: pending](https://img.shields.io/badge/DOI-pending-6b7280)](CITATION.cff)
```

**Replace with:**
```
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19900714.svg)](https://doi.org/10.5281/zenodo.19900714)
```

**Validation:**
```bash
grep -c "DOI-pending" README.md
# Must output: 0
grep -c "zenodo.org/badge/DOI" README.md
# Must output: 1
```

**Commit:** `fix: README DOI badge now links to live Zenodo DOI`

---

## Task 3: Verify governance-interception-layer Link [CRITICAL]

**File:** `README.md`

The README contains a table row linking to `https://github.com/Fulcrum-Governance/governance-interception-layer`. Check if that URL resolves.

```bash
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://github.com/Fulcrum-Governance/governance-interception-layer)
echo "HTTP status: $HTTP_CODE"
```

**If 404:** Replace the table row with:

```markdown
| **governance-interception-layer** | Out-of-process enforcement boundary: transport adapters, shared governance pipeline | Apache 2.0 *(repo creation pending — see [fulcrum-io](https://github.com/Fulcrum-Governance/fulcrum-io))* |
```

Remove the hyperlink from "governance-interception-layer" — make it plain bold text, not a link.

**If 200 or 301:** No change needed. Move to Task 4.

**Commit (if changed):** `fix: mark GIL repo link as pending until repo is created`

---

## Task 4: Remove Tracked Git Artifacts [IMPORTANT]

Check which of these files are tracked in git (not just on disk):

```bash
cd /Users/td/ConceptDev/Projects/Fulcrum-Proofs
git ls-files '*.DS_Store'
git ls-files '.coverage'
git ls-files '.pytest_cache'
git ls-files 'graphify-out'
```

**For each file/directory that IS tracked** (the `git ls-files` command returns a non-empty result), remove it from tracking:

```bash
# Only run these for files that git ls-files confirms are tracked:
git rm --cached '*.DS_Store' 2>/dev/null || true
git rm --cached -r '*/.DS_Store' 2>/dev/null || true
git rm --cached .coverage 2>/dev/null || true
git rm --cached -r .pytest_cache/ 2>/dev/null || true
git rm --cached -r graphify-out/ 2>/dev/null || true
```

Then verify the `.gitignore` already covers these. If `graphify-out/` is NOT in `.gitignore`, add it:

```bash
grep -q "graphify-out/" .gitignore || echo -e "\n# Graphify build output\ngraphify-out/" >> .gitignore
```

**Validation:**
```bash
git ls-files '*.DS_Store' | wc -l
# Must output: 0
git ls-files '.coverage' | wc -l
# Must output: 0
git ls-files '.pytest_cache' | wc -l
# Must output: 0
git ls-files 'graphify-out' | wc -l
# Must output: 0
```

**Commit:** `chore: remove tracked build artifacts and OS metadata from git index`

---

## Task 5: Fix claim_scope.yaml Stale Date [IMPORTANT]

**File:** `claims/claim_scope.yaml`

**Find:**
```yaml
updated_at: 2026-04-02
```

**Replace with:**
```yaml
updated_at: 2026-05-06
```

**Rationale:** C-018, C-020, C-021 closures all happened after April 2. The file already reflects their proven status but the date implies the file hasn't been touched since April 2, which is misleading.

**Validation:**
```bash
python3 -c "import yaml; yaml.safe_load(open('claims/claim_scope.yaml')); print('claim_scope.yaml OK')"
grep "updated_at: 2026-05-06" claims/claim_scope.yaml
# Must output the line
```

**Commit:** `fix: update claim_scope.yaml timestamp to reflect post-Wave-1 state`

---

## Task 6: Harden replay.sh Required Theorems [IMPORTANT]

**File:** `proofs/lean/scripts/replay.sh`

**Find this block:**
```bash
required=(
  "thm_budget_local"
  "thm_privilege_static"
  "thm_temporal_conservation_spec"
)
```

**Replace with:**
```bash
required=(
  "thm_budget_local"
  "thm_privilege_static"
  "thm_temporal_conservation_spec"
  "trust_monotone_decreasing"
  "trust_guaranteed_termination"
  "mixed_nash_exists"
  "fulcrum_poa_bounded"
  "constrained_poa_exact"
  "budget_enforcement_grounds_game"
  "rlm_depth_bounded"
  "rlm_step_decreasing"
)
```

**IMPORTANT:** Before adding each name, verify it actually exists in the Lean source:
```bash
cd /Users/td/ConceptDev/Projects/Fulcrum-Proofs/proofs/lean
for t in trust_monotone_decreasing trust_guaranteed_termination mixed_nash_exists fulcrum_poa_bounded constrained_poa_exact budget_enforcement_grounds_game rlm_depth_bounded rlm_step_decreasing; do
  if rg -q "theorem\s+$t\b" Proofs; then
    echo "FOUND: $t"
  else
    echo "MISSING: $t — DO NOT ADD TO REQUIRED LIST"
  fi
done
```

**Only add theorems that the grep confirms exist.** If any are MISSING, skip them and note which ones in the commit message. Do NOT guess theorem names.

**Validation:**
```bash
# Dry-run the full replay check (without lake build)
cd /Users/td/ConceptDev/Projects/Fulcrum-Proofs/proofs/lean
for t in $(grep -oP '"[^"]*"' scripts/replay.sh | tr -d '"'); do
  if rg -q "theorem\s+$t\b" Proofs; then
    echo "OK: $t"
  else
    echo "FAIL: $t not found in Proofs/"
    exit 1
  fi
done
echo "All required theorems verified"
```

**Commit:** `fix: harden proof-gate with trust, game theory, and RLM required theorems`

---

## Task 7: Move CODEX_SESSION_LOG.md [MINOR]

```bash
mv CODEX_SESSION_LOG.md .claude/CODEX_SESSION_LOG.md
git add .claude/CODEX_SESSION_LOG.md
git rm CODEX_SESSION_LOG.md
```

**Commit:** `chore: move session log to .claude/ (reduce root clutter)`

---

## Task 8: Add "currently unused" Note to Proven-with-sorry Status [MINOR]

**File:** `README.md`

**Find:**
```
| **Proved** | Machine-checkable Lean 4 proof, zero sorry | Budget Safety Invariant |
```

Wait — the status levels table. Find the row for "Proven-with-sorry":

```bash
grep -n "Proven-with-sorry" README.md
```

If found, append " *(currently unused — 0 sorrys repo-wide)*" to the Meaning column of that row.

If NOT found (already removed), skip this task.

**Commit (if changed):** `docs: note Proven-with-sorry status is currently unused`

---

## Final Validation Sequence

Run these in order BEFORE pushing:

```bash
cd /Users/td/ConceptDev/Projects/Fulcrum-Proofs

# 1. Confirm branch
git branch --show-current
# Must output: fix/proofs-repo-audit-2026-05-06

# 2. YAML integrity
python3 -c "import yaml; yaml.safe_load(open('CITATION.cff')); print('CITATION OK')"
python3 -c "import yaml; yaml.safe_load(open('claims/claim_scope.yaml')); print('claim_scope OK')"
python3 -c "import yaml; yaml.safe_load(open('claims/claim_ledger.yaml')); print('claim_ledger OK')"
python3 -c "import yaml; yaml.safe_load(open('claims/theorem_inventory.yaml')); print('theorem_inventory OK')"

# 3. No tracked artifacts
git ls-files '*.DS_Store' '.coverage' '.pytest_cache' 'graphify-out' | wc -l
# Must output: 0

# 4. DOI badge updated
grep -c "DOI-pending" README.md
# Must output: 0

# 5. No sorry regression (source-level check, no build needed)
bash proofs/lean/scripts/check_no_sorry.sh
# Must pass

# 6. Required theorems exist
cd proofs/lean
for t in $(grep -oP '"[^"]*"' scripts/replay.sh | tr -d '"'); do
  rg -q "theorem\s+$t\b" Proofs || { echo "FAIL: $t"; exit 1; }
done
echo "All required theorems verified"
cd ../..

# 7. No Lean files modified (safety check)
git diff --name-only | grep '\.lean$' | head -5
# Must output nothing — this spec does not touch .lean files
```

---

## Push and PR

```bash
git push origin fix/proofs-repo-audit-2026-05-06
```

Create PR targeting `main` with:
- **Title:** `chore: repo audit fixes — DOI, git hygiene, gate hardening`
- **Body:** `Audit fixes from 2026-05-06 strategic review. No Lean proof changes. No compilation changes. Metadata, git tracking hygiene, and CI gate hardening only.`
- **Labels:** `documentation`, `chore`

---

## What NOT To Do

- Do NOT run `lake build` — it takes 20+ minutes and nothing here affects Lean compilation
- Do NOT modify any `.lean` file
- Do NOT change `claim_ledger.yaml` or `theorem_inventory.yaml` content (only `claim_scope.yaml` date)
- Do NOT touch the `proofs/lean/vendor/` directory
- Do NOT create, delete, or rename any branch other than the one specified above
- Do NOT merge the PR — leave it for manual review
- Do NOT install any new dependencies or tools
