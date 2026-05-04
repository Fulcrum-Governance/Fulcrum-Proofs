# Lean 4 Tooling Systems Check + Kakutani Closure Execution

> **STATUS: COMPLETED 2026-04-28.** The Kakutani closure described in Phase 3 was
> executed successfully. Mixed Nash existence (`mixed_nash_exists`) is now
> sorry-free via math-xmum/Brouwer's `ExistsNashEq` (Brouwer fixed-point on
> product simplices via Scarf's Lemma) through a PMF↔stdSimplex bridge; the
> previous `kakutani_fixed_point_theorem` axiom has been removed. Repo is now
> at zero sorrys (`proofs/lean/scripts/check_no_sorry.sh`, empty
> `ALLOWED_OCCURRENCES`). This runbook is preserved as a historical record of
> the systems-check + closure procedure; the in-body "expected" claims have
> been updated to reflect post-closure reality.

## Context

Three Lean 4 tools were just installed for this project:
1. **lean-lsp-mcp** — MCP server providing LSP access (diagnostics, goals, search)
2. **lean4-skills** — Workflow pack with structured prove/review/golf loops
3. **Leanstral** — Mistral's specialized Lean 4 proof agent (via API)

Run this systems check before starting any proof work.

---

## Phase 1: Systems Check (run all of these, report results)

### 1.1 lean-lsp-mcp Verification

Verify the MCP server is accessible and can interact with Fulcrum-Proofs:

```bash
# Check uv is on PATH
source ~/.local/bin/env && which uvx

# Verify lean-lsp-mcp is installed
uvx lean-lsp-mcp --help 2>&1 | head -5

# Verify Claude Code MCP config
cat ~/.claude.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
lsp=d.get('mcpServers',{}).get('lean-lsp',{})
print('TYPE:', lsp.get('type'))
print('CMD:', lsp.get('command'), lsp.get('args'))
print('ENV:', lsp.get('env'))
"

# Verify LEAN_PROJECT_PATH points to correct location
echo $LEAN_PROJECT_PATH
ls $LEAN_PROJECT_PATH/lakefile.lean $LEAN_PROJECT_PATH/lean-toolchain
```

**If lean-lsp-mcp tools are available in this session**, test them:
- Use `lean_file_outline` on `Proofs/GameTheory/MixedNashExistence.lean`
- Use `lean_diagnostics` on the same file (post-closure: no sorry expected)
- Use `leansearch` to search for "PMF simplex conversion"

**Expected (post-closure 2026-04-28):** MCP tools respond. Diagnostics show no sorry remaining. LeanSearch returns relevant Mathlib lemmas.

### 1.2 lean4-skills Verification

```bash
# Verify skill files exist
ls ~/.codex/skills/lean4-skills/plugins/lean4/skills/lean4/SKILL.md

# Verify environment variables
source ~/.zshrc
echo "LEAN4_PLUGIN_ROOT=$LEAN4_PLUGIN_ROOT"
echo "LEAN4_SCRIPTS=$LEAN4_SCRIPTS"
echo "LEAN4_REFS=$LEAN4_REFS"

# Verify scripts are executable
ls $LEAN4_SCRIPTS/*.py 2>/dev/null | head -5

# Run sorry analyzer on Fulcrum-Proofs
cd "$(git rev-parse --show-toplevel)/proofs/lean"
python3 "$LEAN4_SCRIPTS/sorry_analyzer.py" . --format=summary --report-only 2>&1 || echo "sorry_analyzer not found or different interface"
```

**Expected:** SKILL.md exists, env vars are set, scripts directory has Python files.

### 1.3 Leanstral API Verification

```bash
# Verify API key is set
source ~/.zshrc
echo "MISTRAL_API_KEY set: $([ -n "$MISTRAL_API_KEY" ] && echo YES || echo NO)"

# Verify mistralai package
python3 -c "from mistralai.client import Mistral; print('mistralai import OK')"

# Run connectivity test
python3 -c "
import os
from mistralai.client import Mistral
client = Mistral(api_key=os.environ['MISTRAL_API_KEY'])  # raises KeyError if unset
r = client.chat.complete(
    model='labs-leanstral-2603',
    messages=[{'role':'user','content':'In Lean 4, what tactic closes: theorem foo : 1 + 1 = 2 := by sorry. One word answer.'}]
)
print(f'Model: {r.model}')
print(f'Response: {r.choices[0].message.content.strip()[:100]}')
print('LEANSTRAL API OK')
"
```

**Expected:** Leanstral responds with `decide` or `rfl` or `norm_num`. Model name shows `labs-leanstral-2603`.

### 1.4 Lean Build Verification

```bash
# Verify toolchain
cat "$(git rev-parse --show-toplevel)/proofs/lean/lean-toolchain"
# Expected: leanprover/lean4:v4.29.0-rc4

# Verify project builds
cd "$(git rev-parse --show-toplevel)/proofs/lean"
lake build 2>&1 | tail -5

# Count sorrys
grep -rn "sorry" Proofs/GameTheory/ --include="*.lean" | grep -v "\-\-" | grep -v "sorry-free\|no.sorry\|check_no_sorry"

# Run no-sorry gate
bash scripts/check_no_sorry.sh 2>&1
```

**Expected (post-closure 2026-04-28):** Build succeeds. Zero sorrys in `Proofs/GameTheory/**/*.lean`. `check_no_sorry.sh` passes with empty `ALLOWED_OCCURRENCES`.

### 1.5 AGENTS.md Verification

```bash
grep -A 3 "lean-lsp-mcp\|lean4-skills\|Leanstral" "$(git rev-parse --show-toplevel)/AGENTS.md"
```

**Expected:** Lean 4 AI Tooling section present with all three tools documented.

---

## Phase 2: Report

After running all checks, produce a table:

| Tool | Status | Notes |
|------|--------|-------|
| uv/uvx | ? | |
| lean-lsp-mcp (installed) | ? | |
| lean-lsp-mcp (MCP tools available) | ? | |
| lean4-skills (files) | ? | |
| lean4-skills (env vars) | ? | |
| Leanstral API (auth) | ? | |
| Leanstral API (response) | ? | |
| Lean toolchain (v4.29.0-rc4) | ? | |
| lake build | ? | |
| Sorry count (post-closure expected: 0) | ? | |
| check_no_sorry.sh | ? | |
| AGENTS.md | ? | |

If any tool fails, report the exact error. Do not attempt to fix — just report.

---

## Phase 3: Ready for Kakutani Closure

If all checks pass, the environment is ready for the Kakutani closure sprint. The execution spec is at:

```
../Fulcrum/.claude/sprint/papers/d4-advancement/D4-KAKUTANI-CLOSURE-SPEC.md
```

The Codex-reviewed execution plan that supersedes some spec details is in the user's conversation history (titled "D4 Sorry Closure v3 Execution Plan"). Key points from the execution plan:

1. Fork math-xmum/Brouwer, bump to v4.29.0-rc4, count errors (feasibility gate)
2. If < 50 errors: fix them, link as dependency, build bridge module
3. Close mixed_nash_exists via ExistsNashEq bridge
4. Close constrained_welfare_optimal and constrained_poa_exact (same sprint)
5. Fix check_no_sorry.sh for macOS Bash 3.2
6. Update claim registries and paper

**Do not start Phase 3 without explicit user instruction.** This systems check is verification only.
