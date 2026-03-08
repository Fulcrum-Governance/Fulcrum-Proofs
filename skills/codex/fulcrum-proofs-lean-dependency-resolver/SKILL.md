---
name: lean-dependency-resolver
description: >
  Resolve Lean 4 lake dependency conflicts when adding external libraries
  (Mathlib4, harfe/fixed-point-theorems-lean4, math-xmum/Brouwer) to the
  Fulcrum-Proofs lakefile. Use this skill PROACTIVELY whenever modifying
  proofs/lean/lakefile.lean, adding new `require` statements, running
  `lake update`, or encountering Lean toolchain version mismatches. Also
  use when builds fail with import errors, version pinning issues, or
  "unknown package" errors after adding dependencies.
---

# Lean Lake Dependency Resolver

## Why This Skill Exists

Adding multiple external Lean 4 dependencies that each pin their own
Mathlib4 version is the single highest-risk operation in the proof repo.
A version mismatch between Mathlib4, harfe/fixed-point-theorems-lean4,
and math-xmum/Brouwer will cause cascading build failures that are
difficult to diagnose. This skill provides a systematic resolution
protocol.

## The Core Problem

Each external Lean repo typically:
1. Pins a specific `lean-toolchain` version (e.g., `leanprover/lean4:v4.16.0`)
2. Depends on a specific Mathlib4 commit (via `lake-manifest.json`)
3. May use internal names that differ from their GitHub repo name

When you `require` multiple repos in one lakefile, Lake must resolve a
single Mathlib4 version that all dependencies agree on. If they don't
agree, builds fail with opaque errors.

## Resolution Protocol

### Step 1: Inspect Before Modifying

Before touching `lakefile.lean`, inspect all target repos:

```bash
# For each external dependency, check:
# 1. Its lean-toolchain
# 2. Its lakefile.lean (get the exact package name)
# 3. Its lake-manifest.json (get the Mathlib4 commit it pins)

# Example for harfe:
curl -sL https://raw.githubusercontent.com/harfe/fixed-point-theorems-lean4/main/lean-toolchain
curl -sL https://raw.githubusercontent.com/harfe/fixed-point-theorems-lean4/main/lakefile.lean
curl -sL https://raw.githubusercontent.com/harfe/fixed-point-theorems-lean4/main/lake-manifest.json

# Example for math-xmum:
curl -sL https://raw.githubusercontent.com/math-xmum/Brouwer/main/lean-toolchain
curl -sL https://raw.githubusercontent.com/math-xmum/Brouwer/main/lakefile.lean
curl -sL https://raw.githubusercontent.com/math-xmum/Brouwer/main/lake-manifest.json
```

Record:
- Each repo's `lean-toolchain` version
- Each repo's package name (from `package "name"` in lakefile)
- Each repo's Mathlib4 commit SHA (from `lake-manifest.json`)

### Step 2: Find the Common Toolchain

All dependencies must use the same Lean toolchain. If they diverge:

**Option A (preferred):** Find the newest toolchain that all repos support.
Check if the older repos have branches/tags compatible with the newer toolchain.

**Option B:** Fork the out-of-date repo, update its `lean-toolchain` to
match the others, run `lake update` in the fork to pull compatible Mathlib,
verify it builds, push the fork. Point the lakefile at the fork.

**Option C (last resort):** Pin all repos to the oldest common toolchain.
This may lose recent Mathlib features.

### Step 3: Write the Lakefile

The `require` statement must use the exact package name from the repo's
lakefile, not the GitHub repo name. These are often different.

```lean
-- WRONG: using GitHub repo name
require «fixed-point-theorems-lean4» from git
  "https://github.com/harfe/fixed-point-theorems-lean4"

-- RIGHT: using the package name from the repo's lakefile.lean
-- (check what `package "???"` says in their lakefile)
require «the-actual-package-name» from git
  "https://github.com/harfe/fixed-point-theorems-lean4"
```

If a repo has no explicit `@` branch/tag pin, Lake pulls `main`.
To pin a specific commit for reproducibility:

```lean
require «package-name» from git
  "https://github.com/owner/repo" @ "commit-sha-or-tag"
```

### Step 4: Incremental Dependency Addition

Do NOT add all dependencies at once. Add them one at a time:

```
1. Add Mathlib4 alone → lake update → lake build → verify
2. Add harfe/FPT → lake update → lake build → verify
3. Add math-xmum/Brouwer → lake update → lake build → verify
```

If step N fails, you know exactly which dependency caused the conflict.
Fix it before proceeding to N+1.

### Step 5: Verify Existing Proofs

After each dependency addition:

```bash
cd proofs/lean
lake build Proofs          # all existing proofs still compile
lake build                 # full build including new deps
```

If existing proofs break, the new dependency likely pulled a different
Mathlib version that changed an API. Check the Lean build error for which
Mathlib module changed, and update the existing proof to match.

### Step 6: Verify Imported Theorems Are Accessible

After all dependencies are wired:

```bash
# Find the actual module paths
find proofs/lean/.lake/packages/ -name "*.lean" | grep -i kakutani
find proofs/lean/.lake/packages/ -name "*.lean" | grep -i brouwer
find proofs/lean/.lake/packages/ -name "*.lean" | grep -i simplex
```

Write a test import file that references the key theorems:
- Kakutani fixed-point theorem
- Brouwer fixed-point theorem
- Product simplex homeomorphism (if available)

If an import fails with "unknown identifier", the module path is wrong.
Use `lake env printPaths` to see the resolved module root paths.

## Common Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `unknown package 'X'` | Package name in `require` doesn't match repo's `package` declaration | Check repo's `lakefile.lean` for actual name |
| `version solving failed` | Two deps pin conflicting Mathlib commits | Fork older dep, update its Mathlib pin |
| `file not found: Mathlib.X.Y` | Mathlib API changed between versions | Check Mathlib4 changelog, update import path |
| `lean-toolchain mismatch` | Deps use different Lean versions | Align all to one toolchain (Step 2) |
| `Build completed successfully (0 jobs)` but imports fail | Dep built but its modules aren't in the search path | Check `lean_lib` roots in the dep's lakefile |
| `maximum heartbeat exceeded` | Mathlib import is too heavy for a definition | Add `set_option maxHeartbeats 400000` locally |

## Rollback Protocol

If dependency wiring fails completely:

```bash
cd proofs/lean
git checkout -- lakefile.lean lean-toolchain lake-manifest.json
rm -rf .lake/packages  # clear cached packages
lake update            # restore clean state
lake build             # verify rollback works
```

Never commit a broken `lake-manifest.json`. The CI `proof-gate` will reject it.
