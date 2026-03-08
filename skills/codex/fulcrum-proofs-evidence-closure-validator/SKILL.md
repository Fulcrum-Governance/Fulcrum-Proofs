---
name: evidence-closure-validator
description: >
  Validate that Fulcrum-Proofs claim ledger entries are internally consistent,
  all evidence_refs resolve to real non-empty files, theorem inventory matches
  actual Lean modules, and CI gates will pass. Use this skill PROACTIVELY
  before committing changes to claims/, after adding new proofs or evidence
  artifacts, before running `make evidence-gate` or `make audit-gate`, or
  when preparing a PR that touches proof or evidence files. Also use when
  adding new claims (C-018 through C-021) to ensure they meet the repo's
  closure criteria.
---

# Evidence Closure Validator

## Why This Exists

The Fulcrum-Proofs repo enforces a strict policy: claims without closure
artifacts must be marked `Incomplete`. The CI gates (`proof-gate`,
`model-gate`, `evidence-gate`, `audit-gate`) block merges when evidence
is missing or inconsistent. This skill ensures you pass those gates
before pushing.

## Validation Checklist

Run these checks in order. Stop at the first failure and fix it before
proceeding.

### 1. Claim Scope ↔ Claim Ledger Consistency

Every claim in `claims/claim_scope.yaml` must have a matching entry in
`claims/claim_ledger.yaml`, and vice versa.

```bash
# Extract claim IDs from both files and diff
grep 'claim_id:' claims/claim_scope.yaml | sort > /tmp/scope_ids
grep 'claim_id:' claims/claim_ledger.yaml | sort > /tmp/ledger_ids
diff /tmp/scope_ids /tmp/ledger_ids
```

Expected: no diff. If a claim exists in scope but not ledger, it needs
a ledger entry. If it's in ledger but not scope, the scope file is stale.

Status fields must also match between the two files.

### 2. Evidence Refs Resolve to Real Files

Every path in a claim's `evidence_refs` must exist and be non-empty.

```bash
# Extract all evidence_refs and check each exists
python3 -c "
import yaml, sys, os
with open('claims/claim_ledger.yaml') as f:
    data = yaml.safe_load(f)
missing = []
empty = []
for entry in data['entries']:
    for ref in entry.get('evidence_refs', []):
        if not os.path.exists(ref):
            missing.append((entry['claim_id'], ref))
        elif os.path.getsize(ref) == 0:
            empty.append((entry['claim_id'], ref))
if missing:
    print('MISSING evidence refs:', file=sys.stderr)
    for cid, ref in missing:
        print(f'  {cid}: {ref}', file=sys.stderr)
if empty:
    print('EMPTY evidence refs:', file=sys.stderr)
    for cid, ref in empty:
        print(f'  {cid}: {ref}', file=sys.stderr)
sys.exit(1 if missing or empty else 0)
"
```

Common failures:
- Report files not generated yet (run the harness/gate first)
- Path typo (check exact filename including extension)
- File exists but is a `.gitkeep` placeholder (replace with real artifact)

### 3. Theorem Inventory ↔ Lean Source Consistency

Every theorem in `claims/theorem_inventory.yaml` must exist in the
referenced `lean_module` with status matching `proof_status`.

```bash
# Check each theorem exists in its declared module
python3 -c "
import yaml, sys, re
with open('claims/theorem_inventory.yaml') as f:
    data = yaml.safe_load(f)
errors = []
for thm in data['theorems']:
    module_path = 'proofs/lean/' + thm['lean_module']
    tid = thm['theorem_id']
    # Convert THM-BUDGET-LOCAL to thm_budget_local for Lean name matching
    lean_name = tid.lower().replace('-', '_')
    try:
        with open(module_path) as f:
            content = f.read()
        if f'theorem {lean_name}' not in content and f'theorem {lean_name.replace(\"thm_\", \"\")}' not in content:
            # Try a broader search
            if lean_name.replace('thm_', '') not in content.lower():
                errors.append(f'{tid}: theorem not found in {module_path}')
    except FileNotFoundError:
        errors.append(f'{tid}: module {module_path} does not exist')
    if thm['proof_status'] == 'proven':
        # Check for sorry in the specific theorem
        pass  # The no-sorry check covers this globally
for e in errors:
    print(f'ERROR: {e}', file=sys.stderr)
sys.exit(1 if errors else 0)
"
```

### 4. No Sorry Check

```bash
./proofs/lean/scripts/check_no_sorry.sh
```

If this fails, a proof has a `sorry` hole. Find and complete it before
claiming any theorem as proven.

### 5. Lean Build Passes

```bash
cd proofs/lean && lake build Proofs
```

Must complete with no errors. Warnings about `noncomputable` are expected
and acceptable for game theory modules.

### 6. TLA+ Model Check Passes

```bash
# Run all configured TLA+ specs
for cfg in models/tla/configs/*.cfg; do
  spec=$(grep -l "$(basename ${cfg%.cfg})" models/tla/specs/*.tla 2>/dev/null || true)
  if [ -n "$spec" ]; then
    java -jar models/tla/tools/tla2tools.jar -config "$cfg" "$spec"
  fi
done
```

Must end with "Model checking completed. No error has been found."

### 7. Closure Criteria Met

For each claim marked `proven` in `claim_scope.yaml`, verify all
`closure_criteria` are met:

| Criterion | How to Verify |
|-----------|---------------|
| `lake_build_passes` | `lake build Proofs` succeeds |
| `no_sorry_in_proofs` | `check_no_sorry.sh` passes |
| `theorem_inventory_complete` | All THM-* in inventory have `proof_status: proven` |
| `lean_game_definitions_compiled` | `lake build Proofs.GameTheory.Definitions` succeeds |
| `nash_existence_theorem_proven` | `thm_nash_pure_existence` or `thm_nash_mixed_existence` has no sorry |
| `mixed_strategy_nash_existence_proven_via_kakutani` | `MixedNashExistence.lean` builds with no sorry |
| `dsic_theorem_proven` | `IncentiveCompatibility.lean` builds with no sorry |
| `lean_poa_bound_proven` | `CoordinationEfficiency.lean` builds with no sorry |
| `tla_coordination_invariants_hold` | TLC logs show "No error has been found" |
| `simulation_convergence_rate_above_90pct` | `nash-convergence.json` summary shows `nash_equilibrium_rate > 0.9` |
| `bridge_theorem_connects_budget_safety_to_game` | `BudgetGameBridge.lean` builds with no sorry |

### 8. Waiver Validity

For claims marked `incomplete`, verify a valid waiver exists:

```bash
python3 -c "
import yaml, sys
from datetime import date
with open('claims/claim_scope.yaml') as f:
    scope = yaml.safe_load(f)
with open('claims/waivers.yaml') as f:
    waivers = yaml.safe_load(f)
waiver_ids = {w['claim_id'] for w in waivers.get('waivers', [])}
for claim in scope['claims']:
    if claim['status'] == 'incomplete' and claim['claim_id'] not in waiver_ids:
        print(f'ERROR: {claim[\"claim_id\"]} is incomplete but has no waiver', file=sys.stderr)
        sys.exit(1)
# Check waiver expiry
for w in waivers.get('waivers', []):
    exp = w.get('expires_at')
    if exp and date.fromisoformat(str(exp)) < date.today():
        print(f'WARNING: waiver for {w[\"claim_id\"]} expired on {exp}', file=sys.stderr)
print('Waiver check passed')
"
```

## Pre-Commit Quick Check

Before every commit that touches `claims/`, `proofs/`, `models/`, or
`benchmarks/`, run:

```bash
make contracts-check && \
  cd proofs/lean && lake build Proofs && cd ../.. && \
  ./proofs/lean/scripts/check_no_sorry.sh && \
  python3 scripts/evidence_gate.py
```

If any step fails, do not commit. Fix the issue first.

## Adding New Claims (C-018 through C-021)

When adding Nash equilibrium claims, ensure:

1. Add to BOTH `claim_scope.yaml` AND `claim_ledger.yaml`
2. Add all theorems to `theorem_inventory.yaml` with correct:
   - `lean_module` path (relative to `proofs/lean/`)
   - `dependencies` referencing other THM-* IDs
   - `assumptions` listing every A-* assumption
3. Set `status: proven` only AFTER all closure criteria pass
4. Set `status: incomplete` with a waiver if any criteria are unmet
5. Evidence refs must point to files that will exist after the gate run

The claim IDs C-018 through C-021 are reserved for:
- C-018: Nash equilibrium existence
- C-019: Incentive compatibility (DSIC)
- C-020: Price of Anarchy bound
- C-021: Budget-game bridge
