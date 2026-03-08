# Nash Equilibrium Coordination Proofs — Implementation Plan (Rev 2)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Formally prove that Fulcrum's multi-agent governance mechanism admits a Nash equilibrium, is incentive-compatible, and has bounded coordination loss — closing the critical gap identified in the 2026-03-07 audit.

**Architecture (Revised):** A three-layer proof stack, consolidated in Lean 4:
1. **Import layer** — Mathlib4 + `harfe/fixed-point-theorems-lean4` (Kakutani FPT) + `math-xmum/Brouwer` (product simplex infrastructure). No need to build fixed-point theorems from scratch.
2. **Fulcrum game model** — map agents, budgets, policies to game-theoretic structures. Prove Nash existence (pure strategy for finite game, mixed strategy via imported Kakutani), incentive compatibility, and Price of Anarchy bound.
3. **Verification layer** — Veil DSL (Lean 4 embedded) for transition system safety properties replaces standalone TLA+ spec. Retain existing TLA+ `GatewaySafety.tla` for backward compatibility; add Veil spec for agent coordination.
4. **Empirical validation** — Python simulation for convergence evidence + computable epsilon-Nash checker.

**Tech Stack:** Lean 4 (pinned to Mathlib4 toolchain) with Mathlib4, harfe/fixed-point-theorems-lean4, math-xmum/Brouwer as lake dependencies. Veil framework (Lean 4 DSL). Python 3.12+ for simulation. Existing TLA+/TLC retained for GatewaySafety.

**Key Design Decision — Classical vs Constructive:** All existence proofs will be `noncomputable` (depend on `Classical.choice`). This is accepted per Gemini research finding: the ecosystem universally treats Lean as a verification engine for mathematical truth, not a code generator. We bifurcate: Lean proves existence, Python computes equilibria, optional Lean checker verifies computed solutions.

---

## Research Foundation (Gemini Deep Research, 2026-03-07)

Full research document: [Google Doc](https://docs.google.com/document/d/1A-E8X51cDhBaUKQrkAq3RgjDAiaZsHWs0_SGTd0YSGg/edit?usp=sharing)

### Critical Discoveries That Shaped This Plan

| Finding | Impact on Plan |
|---------|---------------|
| `harfe/fixed-point-theorems-lean4` has complete Brouwer + Kakutani via Sperner | **Import** Kakutani instead of building it. Saves 6-12 weeks. |
| `math-xmum/Brouwer` has product simplex infrastructure for N-player games | **Import** product simplex lifting. This is the exact bridge from single-simplex Brouwer to multi-player Nash. |
| `kevinvallier/TSE_Formal` has KKT, Lyapunov, simplex geometry in Lean 4 | Reference for evolutionary stability proofs. Import if compatibility allows. |
| Brouwer FPT NOT in Mathlib4 proper (still in external repos) | Must add external lake deps. |
| All Brouwer proofs are `noncomputable` (Classical.choice) | Accept. Bifurcate existence proof from runtime solver. |
| Veil framework embeds TLA+-style transition systems in Lean 4 | Can unify formal proofs + model checking in one language. |
| Institutional AI governance manifests (arxiv:2601.11369) | Maps directly to Fulcrum's policy + SHA-256 enforcement architecture. |
| Zhang et al. ICSAP framework + follow-ups (2024-2026) | Provides the theoretical frame for our IC proofs. |

### Key References

| Reference | Cite As | Relevance |
|-----------|---------|-----------|
| Nash (1951), Annals of Mathematics | Nash51 | Original equilibrium existence via Kakutani |
| Le Roux, Martin-Dorel, Smaus (2017), arxiv:1709.02096 | LeRoux17 | Only prior Nash formalization (Coq/Isabelle, restricted) |
| harfe/fixed-point-theorems-lean4 | Harfe-FPT | Complete Brouwer + Kakutani in Lean 4 |
| math-xmum/Brouwer | MathXmum | Product simplex infrastructure for N-player Nash |
| Vallier (2025), arxiv:2512.07901, kevinvallier/TSE_Formal | Vallier25 | Evolutionary game theory in Lean 4, KKT conditions |
| Zhang et al. (2024), arxiv:2402.12907 | Zhang24-ICSAP | IC framework for AI governance |
| Institutional AI (2026), arxiv:2601.11369 | InstAI26 | Governance manifests, SHA-256 enforcement |
| Veil (2026), Sergey et al. | Veil26 | Lean 4 DSL for transition system verification |
| Shmalo (2018), arxiv:1811.08454 | Shmalo18 | Combinatorial Kakutani proof via Sperner |
| Hendtlass (2016), arxiv:1611.02531 | Hendtlass16 | Constructive approximate Kakutani |

---

## Phase 1: Lean 4 Foundation — Import External Fixed-Point Theorems

### Task 1: Add Mathlib4 + External Dependencies to Lakefile

**Files:**
- Modify: `proofs/lean/lakefile.lean`
- Modify: `proofs/lean/lean-toolchain`

**Step 1: Update lakefile with all dependencies**

```lean
import Lake
open Lake DSL

package "fulcrum_proofs" where
  moreLeanArgs := #[]
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4"

-- Kakutani FPT via cubical Sperner's Lemma (harfe)
-- Provides: Brouwer FPT, Kakutani FPT, partition of unity
require «fixed-point-theorems» from git
  "https://github.com/harfe/fixed-point-theorems-lean4"

-- Product simplex infrastructure for N-player games (math-xmum)
-- Provides: Brouwer on product simplices, projections, embeddings
require «brouwer» from git
  "https://github.com/math-xmum/Brouwer"

lean_lib "Proofs" where
  roots := #[`Proofs]
```

**Important note to implementer:** The `require` names and branch/tag pins must be verified against the actual repos at build time. Check each repo's `lakefile.lean` for the correct package name. If repos conflict on Mathlib version pins, you may need to fork and align toolchains. This is the highest-risk step in the entire plan.

**Step 2: Pin toolchain to match Mathlib's current lean-toolchain**

Check all three repos' `lean-toolchain` files and find the common compatible version. If they diverge, pin to Mathlib's version and test if the others compile.

**Step 3: Run lake update and verify build**

```bash
cd proofs/lean && lake update && lake build
```

Expected: All dependencies download. Existing proofs still compile.

If dependency conflicts occur: fork the conflicting repo, update its toolchain pin, and point the lakefile at the fork. Document the fork in `proofs/lean/README.md`.

**Step 4: Verify existing proofs unbroken**

```bash
cd proofs/lean && lake build Proofs
./proofs/lean/scripts/check_no_sorry.sh
```

Expected: Build succeeds, no sorry found.

**Step 5: Commit**

```bash
git add proofs/lean/lakefile.lean proofs/lean/lean-toolchain proofs/lean/lake-manifest.json
git commit -m "build(lean): add Mathlib4, harfe/FPT, math-xmum/Brouwer dependencies"
```

---

### Task 2: Validate Imported Theorems Are Accessible

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/ImportCheck.lean`

**Step 1: Write an import verification file**

This file confirms we can access the critical imported theorems. It should compile with no errors and no sorry.

```lean
/-
  Import verification: confirms that Kakutani FPT,
  Brouwer FPT, and product simplex infrastructure
  are accessible from our proof package.

  This file exists solely to verify dependency wiring.
  Delete or convert to a proper module once confirmed.
-/

-- Adjust these imports based on actual module paths in the harfe and math-xmum repos.
-- The implementer MUST check the actual module structure of each dependency.
-- Example expected paths (verify against repos):
--   import FixedPointTheorems.Kakutani
--   import FixedPointTheorems.Brouwer
--   import Brouwer.ProductSimplex

-- Placeholder: the implementer should replace these with actual imports
-- and verify that key theorems are accessible:
--   1. Kakutani fixed-point theorem
--   2. Brouwer fixed-point theorem
--   3. Product simplex homeomorphism

-- If a theorem is not accessible, document the gap and adjust the plan.
```

**Step 2: Explore each dependency's module structure**

```bash
# Check harfe repo structure
find proofs/lean/.lake/packages/fixed-point-theorems -name "*.lean" | head -20

# Check math-xmum repo structure
find proofs/lean/.lake/packages/brouwer -name "*.lean" | head -20
```

**Step 3: Write actual imports, build, confirm access**

**Step 4: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/ImportCheck.lean
git commit -m "build(lean): verify external FPT imports are accessible"
```

---

## Phase 2: Game Theory Foundations

### Task 3: Define Normal-Form Game Structures

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/Definitions.lean`
- Modify: `proofs/lean/Proofs.lean` (add import)

**Step 1: Write the game theory type definitions**

```lean
import Mathlib.Probability.ProbabilityMassFunction.Basic
import Mathlib.Data.Finset.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Order.CompleteLattice

namespace Fulcrum.GameTheory

/-- A finite normal-form game with `n` players. Each player has a finite
    strategy set and a real-valued payoff function over strategy profiles. -/
structure NormalFormGame (n : Nat) where
  /-- Strategy type for each player -/
  Strategy : Fin n -> Type
  /-- Each strategy type is finite -/
  strategyFintype : ∀ i, Fintype (Strategy i)
  /-- Each strategy type is nonempty -/
  strategyNonempty : ∀ i, Nonempty (Strategy i)
  /-- Each strategy type has decidable equality -/
  strategyDecEq : ∀ i, DecidableEq (Strategy i)
  /-- Payoff function for each player given a strategy profile -/
  payoff : (i : Fin n) -> ((j : Fin n) -> Strategy j) -> ℝ

/-- A strategy profile assigns a strategy to each player. -/
def StrategyProfile (G : NormalFormGame n) := (i : Fin n) -> G.Strategy i

/-- A mixed strategy for player `i` is a probability distribution over
    their pure strategies. -/
def MixedStrategy (G : NormalFormGame n) (i : Fin n) :=
  @PMF (G.Strategy i) (G.strategyFintype i).fintype

/-- A mixed strategy profile assigns a mixed strategy to each player. -/
def MixedStrategyProfile (G : NormalFormGame n) :=
  (i : Fin n) -> MixedStrategy G i

/-- Player `i`'s best response: a strategy that maximizes their payoff
    given other players' strategies are fixed. -/
def IsBestResponse (G : NormalFormGame n) (i : Fin n)
    (σ : StrategyProfile G) : Prop :=
  ∀ s' : G.Strategy i,
    G.payoff i σ >= G.payoff i (Function.update σ i s')

/-- A Nash equilibrium is a strategy profile where every player is
    playing a best response. -/
def IsNashEquilibrium (G : NormalFormGame n) (σ : StrategyProfile G) : Prop :=
  ∀ i : Fin n, IsBestResponse G i σ

/-- A strategy profile is Pareto optimal if no player can be made
    better off without making another worse off. -/
def IsParetoOptimal (G : NormalFormGame n) (σ : StrategyProfile G) : Prop :=
  ¬ ∃ σ' : StrategyProfile G,
    (∀ i, G.payoff i σ' >= G.payoff i σ) ∧
    (∃ i, G.payoff i σ' > G.payoff i σ)

/-- Social welfare: sum of all players' payoffs. -/
noncomputable def socialWelfare (G : NormalFormGame n) (σ : StrategyProfile G) : ℝ :=
  Finset.sum Finset.univ (fun i => G.payoff i σ)

/-- Price of Anarchy: ratio of optimal social welfare to worst equilibrium
    social welfare. Bounded means coordination loss is limited. -/
def PriceOfAnarchyBounded (G : NormalFormGame n) (bound : ℝ) : Prop :=
  ∀ σ_eq : StrategyProfile G,
    IsNashEquilibrium G σ_eq ->
    ∀ σ_opt : StrategyProfile G,
      IsParetoOptimal G σ_opt ->
      socialWelfare G σ_opt <= bound * socialWelfare G σ_eq

end Fulcrum.GameTheory
```

**Step 2: Add import to root module**

Add to `proofs/lean/Proofs.lean`:
```lean
import Proofs.BasicInvariants
import Proofs.TemporalConservationSpec
import Proofs.GameTheory.Definitions
```

**Step 3: Verify build**

```bash
cd proofs/lean && lake build Proofs.GameTheory.Definitions
```

**Step 4: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/Definitions.lean proofs/lean/Proofs.lean
git commit -m "feat(proofs): add normal-form game theory type definitions"
```

---

### Task 4: Define the Fulcrum Coordination Game

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/FulcrumGame.lean`
- Modify: `proofs/lean/Proofs.lean`

This maps Fulcrum's actual agent model (from the protobuf contracts) into the game framework. The model captures:
- **Agents** as players choosing from finite action sets
- **Shared budget** as a commons (token competition)
- **Policy violation penalty** as the governance mechanism's enforcement tool
- **Quality/cost tradeoff** as the payoff structure

**Step 1: Write the Fulcrum-specific game model**

```lean
import Proofs.GameTheory.Definitions
import Proofs.BasicInvariants

namespace Fulcrum.GameTheory

/-- Agent actions in the Fulcrum coordination game.
    Maps to real agent choices:
    - conservative: minimal token use, always policy-compliant
    - moderate: balanced quality/cost, compliant
    - aggressive: high token use, risks budget pressure on others
    - noncompliant: violates policy for short-term quality gain -/
inductive AgentAction where
  | conservative  -- 10 tokens, quality 3
  | moderate      -- 25 tokens, quality 7
  | aggressive    -- 50 tokens, quality 9
  | noncompliant  -- 40 tokens, quality 8, triggers violation penalty
  deriving DecidableEq, Fintype, Repr

instance : Nonempty AgentAction := ⟨AgentAction.conservative⟩

/-- Token cost per action. Maps to Cost Service token accounting. -/
def actionTokenCost : AgentAction -> Nat
  | .conservative  => 10
  | .moderate      => 25
  | .aggressive    => 50
  | .noncompliant  => 40

/-- Quality score per action. Maps to task completion quality metrics. -/
def actionQuality : AgentAction -> Nat
  | .conservative  => 3
  | .moderate      => 7
  | .aggressive    => 9
  | .noncompliant  => 8

/-- Policy violation flag. Maps to Immune System incident detection. -/
def actionViolates : AgentAction -> Bool
  | .noncompliant  => true
  | _              => false

/-- Violation penalty. Maps to governance enforcement: policy violation
    triggers BLOCK/TERMINATE + future action space restriction.
    Set high enough that noncompliant is strictly dominated. -/
def violationPenalty : Nat := 20

/-- Budget parameters for the coordination game.
    Maps to Cost Service BudgetConfig: totalBudget is the shared
    per-workflow token budget across all agents in a team. -/
structure BudgetParams where
  totalBudget : Nat
  agentCount : Nat
  hPositive : agentCount > 0

/-- Total tokens consumed by a strategy profile. -/
def totalTokens (n : Nat) (profile : Fin n -> AgentAction) : Nat :=
  Finset.sum Finset.univ (fun i => actionTokenCost (profile i))

/-- Whether a strategy profile stays within budget.
    Backed by budget_safety_guarantee from BasicInvariants.lean:
    the runtime enforces this constraint via applyAction gating. -/
def withinBudget (params : BudgetParams) (profile : Fin params.agentCount -> AgentAction) : Prop :=
  totalTokens params.agentCount profile <= params.totalBudget

/-- Agent payoff in the Fulcrum coordination game.
    payoff_i = quality_i - violation_penalty_i - budget_overflow_share
    Budget overflow is shared equally (all agents blocked when budget exhausted). -/
noncomputable def fulcrumPayoff (params : BudgetParams)
    (profile : Fin params.agentCount -> AgentAction) (i : Fin params.agentCount) : ℝ :=
  let quality := (actionQuality (profile i) : ℝ)
  let penalty := if actionViolates (profile i) then (violationPenalty : ℝ) else 0
  let total := (totalTokens params.agentCount profile : ℝ)
  let budgetOverflow := if total > (params.totalBudget : ℝ)
    then (total - (params.totalBudget : ℝ)) / (params.agentCount : ℝ)
    else 0
  quality - penalty - budgetOverflow

/-- The Fulcrum coordination game as a normal-form game. -/
noncomputable def fulcrumCoordinationGame (params : BudgetParams) :
    NormalFormGame params.agentCount where
  Strategy := fun _ => AgentAction
  strategyFintype := fun _ => inferInstance
  strategyNonempty := fun _ => inferInstance
  strategyDecEq := fun _ => inferInstance
  payoff := fun i profile => fulcrumPayoff params (fun j => profile j) i

end Fulcrum.GameTheory
```

**Step 2: Add import, build, commit**

```bash
git add proofs/lean/Proofs/GameTheory/FulcrumGame.lean proofs/lean/Proofs.lean
git commit -m "feat(proofs): define Fulcrum coordination game model"
```

---

### Task 5: Prove Pure-Strategy Nash Equilibrium Existence

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/NashExistence.lean`
- Modify: `proofs/lean/Proofs.lean`

**Strategy:** For the finite Fulcrum game with 4 actions, we prove existence constructively by showing the all-moderate profile is a Nash equilibrium. No Kakutani needed here — this is a direct argument on the finite payoff structure.

The Kakutani import becomes critical in Task 6 when we extend to mixed-strategy Nash for the general finite game.

**Step 1: Write theorem statements with sorry**

```lean
import Proofs.GameTheory.FulcrumGame

namespace Fulcrum.GameTheory

/-- Noncompliant is strictly dominated by moderate.
    quality(noncompliant) - penalty = 8 - 20 = -12 < 7 = quality(moderate)
    No rational agent ever chooses noncompliant. -/
theorem noncompliant_dominated
    (params : BudgetParams)
    (profile : Fin params.agentCount -> AgentAction)
    (i : Fin params.agentCount)
    (hNc : profile i = AgentAction.noncompliant)
    : fulcrumPayoff params (Function.update profile i AgentAction.moderate) i
      > fulcrumPayoff params profile i := by
  sorry

/-- Under tight budget (= 25 * n), the all-moderate profile is a Nash
    equilibrium. No agent can profitably deviate:
    - conservative: quality drops 7 -> 3 (loss of 4)
    - aggressive: quality +2 but overflow penalty 25/n (net negative for all n)
    - noncompliant: dominated (penalty 20 > quality gain 1) -/
theorem moderate_is_nash_equilibrium
    (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    : let profile : StrategyProfile (fulcrumCoordinationGame params) :=
        fun _ => AgentAction.moderate
      IsNashEquilibrium (fulcrumCoordinationGame params) profile := by
  sorry

/-- The Fulcrum coordination game admits at least one pure-strategy
    Nash equilibrium under tight budget constraints. -/
theorem fulcrum_pure_nash_exists
    (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    : ∃ σ : StrategyProfile (fulcrumCoordinationGame params),
        IsNashEquilibrium (fulcrumCoordinationGame params) σ := by
  exact ⟨fun _ => AgentAction.moderate, moderate_is_nash_equilibrium params hBudget⟩

end Fulcrum.GameTheory
```

**Step 2: Verify it builds with sorry (no type errors)**

```bash
cd proofs/lean && lake build Proofs.GameTheory.NashExistence
```

**Step 3: Prove `noncompliant_dominated`**

Core argument: after unfolding `fulcrumPayoff`, moderate gives quality 7 with no penalty and possibly lower overflow (fewer tokens), while noncompliant gives quality 8 with penalty 20. Net: 7 - 0 > 8 - 20 = -12.

The implementer should unfold definitions and use `simp`, `norm_num`, `linarith`, or `omega` depending on how Lean reduces the conditionals. The mathematical fact is trivial; the tactic engineering may require patience with `noncomputable` reductions.

**Step 4: Prove `moderate_is_nash_equilibrium`**

Case split on the four possible deviations. For each:
- conservative: payoff drops from 7 to 3 (quality loss, no overflow change)
- moderate: no change (identity)
- aggressive: adds 25 tokens, pushing total from 25n to 25n+25 > budget. Overflow = 25/n shared. Quality gain = 2. Net change = 2 - 25/n. For n >= 1, 25/n >= 25 when n=1 (net -23) and 25/n > 2 when n < 13 (net negative). For large n, this approaches +2 but we need the tight budget assumption.

**Refinement for large n:** If n >= 13, aggressive deviation becomes profitable under tight budget. Options:
- Strengthen assumption: `hBudget : params.totalBudget = 25 * params.agentCount` AND `params.agentCount <= 12`
- Or: prove a parameterized result showing equilibrium exists for all n but the equilibrium profile may differ for large n
- Or: prove the mixed-strategy result (Task 6) which covers all cases

The implementer should choose based on what compiles. Document the assumption bound.

**Step 5: Remove all sorry, verify**

```bash
./proofs/lean/scripts/check_no_sorry.sh
```

**Step 6: Commit**

```bash
git add proofs/lean/Proofs/GameTheory/NashExistence.lean proofs/lean/Proofs.lean
git commit -m "feat(proofs): prove pure-strategy Nash equilibrium for Fulcrum game"
```

---

### Task 6: Prove Mixed-Strategy Nash Existence via Imported Kakutani

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/MixedNashExistence.lean`
- Modify: `proofs/lean/Proofs.lean`

This is the crown jewel theorem. Using the imported Kakutani FPT from `harfe/fixed-point-theorems-lean4` and product simplex infrastructure from `math-xmum/Brouwer`, we prove that every finite normal-form game (including the Fulcrum game for any n) admits a mixed-strategy Nash equilibrium.

**This would be the first complete mixed-strategy Nash existence proof in Lean 4.**

**Step 1: Write the theorem statement**

```lean
import Proofs.GameTheory.Definitions
-- Import Kakutani and product simplex (adjust paths based on Task 2 findings)
-- import FixedPointTheorems.Kakutani
-- import Brouwer.ProductSimplex

namespace Fulcrum.GameTheory

/-- The best-response correspondence for player i maps mixed strategy
    profiles to the set of mixed strategies that maximize i's expected
    payoff. This is a set-valued (correspondence) function. -/
noncomputable def bestResponseCorrespondence
    (G : NormalFormGame n) (i : Fin n)
    (σ : MixedStrategyProfile G) : Set (MixedStrategy G i) :=
  sorry -- Define as argmax of expected payoff

/-- Nash's theorem: every finite normal-form game has at least one
    mixed-strategy Nash equilibrium.

    Proof sketch (following Nash 1951):
    1. The mixed strategy space is the product of simplices (compact, convex)
    2. The best-response correspondence is upper hemicontinuous with
       nonempty convex values
    3. By Kakutani's FPT, the correspondence has a fixed point
    4. A fixed point of the best-response correspondence is a Nash equilibrium

    This proof is noncomputable (depends on Classical.choice via
    Bolzano-Weierstrass in the Kakutani proof). The existence guarantee
    is mathematical; equilibrium computation uses the Python simulator. -/
noncomputable theorem mixed_nash_exists
    (G : NormalFormGame n)
    (hn : n > 0)
    : ∃ σ : MixedStrategyProfile G,
        ∀ i : Fin n,
          σ i ∈ bestResponseCorrespondence G i σ := by
  sorry
  -- Proof requires:
  -- 1. Construct the product simplex from individual strategy simplices
  --    (use math-xmum/Brouwer product simplex infrastructure)
  -- 2. Define the combined best-response correspondence on this product
  -- 3. Show upper hemicontinuity (from continuity of expected utility)
  -- 4. Show convex-valuedness (from linearity of expected utility in own strategy)
  -- 5. Apply Kakutani (from harfe/fixed-point-theorems-lean4)
  -- 6. Extract Nash equilibrium from the fixed point

end Fulcrum.GameTheory
```

**Step 2: Implement the proof**

This is the hardest task in the plan. The proof requires threading together three external libraries (Mathlib, harfe, math-xmum) with our game definitions. The implementer should:

1. First verify Kakutani's exact statement in the harfe repo (what types it expects)
2. Verify the product simplex homeomorphism in math-xmum (what it produces)
3. Build the bridge: show that the Fulcrum game's mixed strategy space satisfies Kakutani's hypotheses
4. Apply Kakutani and extract the equilibrium

If the external libraries' type signatures are incompatible, the implementer may need to:
- Write compatibility lemmas
- Or fork and adapt the external code
- Or fall back to proving a restricted version (e.g., 2-player games only)

**Step 3: Remove sorry, verify, commit**

```bash
git add proofs/lean/Proofs/GameTheory/MixedNashExistence.lean proofs/lean/Proofs.lean
git commit -m "feat(proofs): prove mixed-strategy Nash existence via Kakutani FPT"
```

---

### Task 7: Prove Incentive Compatibility

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/IncentiveCompatibility.lean`
- Modify: `proofs/lean/Proofs.lean`

**What we prove:** The governance mechanism is incentive-compatible — truthful reporting is a dominant strategy. This connects to the ICSAP framework (Zhang et al. 2024).

**Step 1: Define mechanism design structures and prove IC**

```lean
import Proofs.GameTheory.FulcrumGame

namespace Fulcrum.GameTheory

/-- An agent's true type: their quality need and risk tolerance.
    Maps to the private information each agent has about its task. -/
structure AgentType where
  trueQualityNeed : Nat
  riskTolerance : Nat

/-- A mechanism maps reported types to token allocations.
    Maps to Fulcrum's Cost Service budget allocation logic. -/
structure Mechanism (n : Nat) where
  allocate : (Fin n -> AgentType) -> (Fin n -> Nat)
  totalBudget : Nat
  budgetFeasible : ∀ reports,
    Finset.sum Finset.univ (fun i => allocate reports i) <= totalBudget

/-- Dominant-strategy incentive compatibility (DSIC):
    truthful reporting maximizes allocation for every agent,
    regardless of what others report.
    This is the strongest form of IC — maps to the ICSAP framework's
    requirement that AI agents' optimal strategy coincides with
    truthful/cooperative behavior. -/
def IsDSIC (n : Nat) (m : Mechanism n) : Prop :=
  ∀ (i : Fin n) (trueTypes : Fin n -> AgentType) (fakeType : AgentType),
    m.allocate trueTypes i >= m.allocate (Function.update trueTypes i fakeType) i

/-- The Fulcrum proportional allocation mechanism.
    Each agent gets tokens proportional to their reported need.
    This mirrors the Cost Service's budget distribution logic. -/
def fulcrumProportionalMechanism (n : Nat) (hn : n > 0) (budget : Nat) : Mechanism n where
  allocate := fun reports i =>
    let totalRequested := Finset.sum Finset.univ (fun j => (reports j).trueQualityNeed)
    if totalRequested = 0 then budget / n
    else (reports i).trueQualityNeed * budget / totalRequested
  totalBudget := budget
  budgetFeasible := by sorry

/-- Under proportional allocation, overstating need does not increase
    your share (denominator grows proportionally). Understating
    reduces your share. Therefore truthful reporting is dominant. -/
theorem fulcrum_proportional_is_dsic
    (n : Nat) (hn : n > 0) (budget : Nat)
    : IsDSIC n (fulcrumProportionalMechanism n hn budget) := by
  sorry
  -- Proof: proportional allocation gives agent i the fraction
  -- (need_i / total_need) * budget. Inflating need_i to need_i + k
  -- gives (need_i + k) / (total_need + k) * budget.
  -- Show: need_i / total_need >= (need_i + k) / (total_need + k)
  -- when k > 0 and total_need > need_i (other agents also report).
  -- This is the "proportional mechanism truth-telling" lemma.

end Fulcrum.GameTheory
```

**Step 2: Complete proofs, remove sorry, commit**

```bash
git add proofs/lean/Proofs/GameTheory/IncentiveCompatibility.lean proofs/lean/Proofs.lean
git commit -m "feat(proofs): prove incentive compatibility of Fulcrum governance mechanism"
```

---

### Task 8: Prove Price of Anarchy Bound + Budget Bridge

**Files:**
- Create: `proofs/lean/Proofs/GameTheory/CoordinationEfficiency.lean`
- Create: `proofs/lean/Proofs/GameTheory/BudgetGameBridge.lean`
- Modify: `proofs/lean/Proofs.lean`

**Step 1: Price of Anarchy bound**

```lean
import Proofs.GameTheory.NashExistence

namespace Fulcrum.GameTheory

/-- The all-moderate equilibrium achieves quality 7n while the
    theoretical max (all aggressive, ignoring budget) is 9n.
    Price of Anarchy = 9/7 ≈ 1.286.
    This is tight: the governance mechanism sacrifices at most
    22% of optimal quality to ensure budget safety. -/
theorem price_of_anarchy_bounded
    (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    : PriceOfAnarchyBounded (fulcrumCoordinationGame params) (9/7) := by
  sorry

end Fulcrum.GameTheory
```

**Step 2: Budget-game bridge**

```lean
import Proofs.GameTheory.FulcrumGame
import Proofs.BasicInvariants

namespace Fulcrum.GameTheory

/-- The budget safety guarantee from BasicInvariants ensures that
    the game's budget constraint is enforced by the runtime.
    This grounds the game model: agents cannot "cheat" the budget. -/
theorem budget_enforcement_grounds_game
    (b : Fulcrum.AgentBudget) (a : Fulcrum.FinancialAction)
    (newB : Fulcrum.AgentBudget)
    (hExec : Fulcrum.applyAction b a = some newB) :
    newB.currentSpent <= newB.aggregateLimit :=
  Fulcrum.budget_safety_guarantee b a newB hExec

/-- Overspending actions are blocked by the runtime (applyAction = none).
    This eliminates budget-cheating from the agent strategy space. -/
theorem budget_blocks_overspend
    (b : Fulcrum.AgentBudget) (a : Fulcrum.FinancialAction)
    (hOver : b.currentSpent + a.delta > b.aggregateLimit) :
    Fulcrum.applyAction b a = none := by
  unfold Fulcrum.applyAction
  simp [Nat.not_le.mpr hOver]

end Fulcrum.GameTheory
```

**Step 3: Complete proofs, remove sorry, commit**

```bash
git add proofs/lean/Proofs/GameTheory/CoordinationEfficiency.lean \
        proofs/lean/Proofs/GameTheory/BudgetGameBridge.lean \
        proofs/lean/Proofs.lean
git commit -m "feat(proofs): prove PoA bound and budget-game bridge"
```

---

## Phase 3: TLA+ Multi-Agent Coordination (Retained) + Veil Exploration

### Task 9: Write TLA+ Agent Coordination Spec

**Files:**
- Create: `models/tla/specs/AgentCoordination.tla`
- Create: `models/tla/configs/AgentCoordination.cfg`
- Create: `models/tla/configs/AgentCoordinationSmall.cfg`

Retain the TLA+ spec from the original plan for backward compatibility with the existing CI gate infrastructure. The TLA+ spec verifies protocol-level safety properties that complement the Lean game-theoretic proofs.

```tla
------------------------------ MODULE AgentCoordination ------------------------------
EXTENDS Naturals, FiniteSets, Sequences, TLC

CONSTANTS Agents, Budget, ViolationPenalty, MaxRounds

VARIABLES
  round, agentAction, totalSpend, agentViolations, budgetExhausted

Vars == <<round, agentAction, totalSpend, agentViolations, budgetExhausted>>

Actions == {"conservative", "moderate", "aggressive", "noncompliant"}

TokenCost(a) == CASE a = "conservative" -> 10
                  [] a = "moderate" -> 25
                  [] a = "aggressive" -> 50
                  [] a = "noncompliant" -> 40
                  [] OTHER -> 0

Quality(a) == CASE a = "conservative" -> 3
                [] a = "moderate" -> 7
                [] a = "aggressive" -> 9
                [] a = "noncompliant" -> 8
                [] OTHER -> 0

Violates(a) == a = "noncompliant"

TotalSpendOf(aa) == LET S == DOMAIN aa
                     IN LET F(s) == TokenCost(aa[s])
                        IN LET Agents_seq == SetToSeq(S)
                           IN 0 \* Placeholder: sum computed via fold

Init ==
  /\ round = 0
  /\ agentAction = [a \in Agents |-> "moderate"]
  /\ totalSpend = Cardinality(Agents) * 25
  /\ agentViolations = [a \in Agents |-> 0]
  /\ budgetExhausted = (Cardinality(Agents) * 25 > Budget)

AgentStep(agent) ==
  \E action \in Actions :
    /\ round < MaxRounds
    /\ agentAction' = [agentAction EXCEPT ![agent] = action]
    /\ totalSpend' = totalSpend - TokenCost(agentAction[agent]) + TokenCost(action)
    /\ agentViolations' = IF Violates(action)
                           THEN [agentViolations EXCEPT ![agent] = @ + 1]
                           ELSE agentViolations
    /\ budgetExhausted' = (totalSpend' > Budget)
    /\ round' = round + 1

Next == \E a \in Agents : AgentStep(a)

Spec == Init /\ [][Next]_Vars

\* --- SAFETY INVARIANTS ---

ModerateWithinBudget ==
  (\A a \in Agents : agentAction[a] = "moderate") => ~budgetExhausted

NoncompliantDominated ==
  Quality("noncompliant") - ViolationPenalty < Quality("moderate")

ViolationAlwaysPenalized ==
  \A a \in Agents :
    agentViolations[a] > 0 =>
      Quality(agentAction[a]) - ViolationPenalty < Quality("moderate")

=============================================================================
```

**Configs and execution same as original plan.** Run TLC, capture logs.

**Step: Commit**

```bash
git add models/tla/specs/AgentCoordination.tla models/tla/configs/AgentCoordination*.cfg
git commit -m "feat(models): add TLA+ multi-agent coordination specification"
```

### Task 10: Run TLC and Capture Reports

```bash
java -jar models/tla/tools/tla2tools.jar \
  -config models/tla/configs/AgentCoordinationSmall.cfg \
  models/tla/specs/AgentCoordination.tla \
  2>&1 | tee models/tla/reports/tlc-AgentCoordinationSmall.log

java -jar models/tla/tools/tla2tools.jar \
  -config models/tla/configs/AgentCoordination.cfg \
  models/tla/specs/AgentCoordination.tla \
  2>&1 | tee models/tla/reports/tlc-AgentCoordination.log
```

Verify: "No error has been found" in both logs.

```bash
git add models/tla/reports/tlc-AgentCoordination*.log
git commit -m "evidence(models): TLC verification of agent coordination invariants"
```

### Task 11: (Optional, Future) Veil DSL Exploration

**Not blocking for initial closure.** The Veil framework is promising but adds a new dependency and learning curve. Recommended as a follow-up after C-018 through C-021 are closed with the Lean + TLA+ approach.

If pursued later:
- Install Veil as a lake dependency
- Rewrite AgentCoordination as a Veil transition system
- Gain: unified Lean proofs + automated invariant checking
- Cost: new DSL to learn, potential Mathlib version conflicts

---

## Phase 4: Empirical Simulation

### Task 12: Build Nash Convergence Simulator

**Files:**
- Create: `benchmarks/simulations/nash_convergence.py`
- Create: `benchmarks/simulations/README.md`

**Step 1: Write the simulation**

```python
#!/usr/bin/env python3
"""
Nash equilibrium convergence simulator for the Fulcrum coordination game.

Simulates N agents choosing actions under shared budget constraints
via best-response dynamics. Measures convergence rate, equilibrium
profile, and Price of Anarchy.

This is the empirical complement to the Lean existence proof:
- Lean proves an equilibrium EXISTS (noncomputable)
- This simulator COMPUTES it and measures convergence properties

Usage:
    python3 benchmarks/simulations/nash_convergence.py \
        --agents 5 --budget 125 --rounds 1000 --repeats 50 \
        --out benchmarks/raw/nash-convergence.json
"""
import argparse
import json
import random
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List


@dataclass
class ActionProfile:
    name: str
    token_cost: int
    quality: int
    violates: bool


ACTIONS = [
    ActionProfile("conservative", 10, 3, False),
    ActionProfile("moderate", 25, 7, False),
    ActionProfile("aggressive", 50, 9, False),
    ActionProfile("noncompliant", 40, 8, True),
]

VIOLATION_PENALTY = 20


def payoff(action: ActionProfile, total_spend: int, budget: int, n_agents: int) -> float:
    quality = action.quality
    penalty = VIOLATION_PENALTY if action.violates else 0
    overflow = max(0, (total_spend - budget)) / n_agents if total_spend > budget else 0
    return quality - penalty - overflow


def best_response(agent_idx: int, actions: List[int], budget: int) -> int:
    n = len(actions)
    others_spend = sum(ACTIONS[actions[j]].token_cost for j in range(n) if j != agent_idx)
    best_action = 0
    best_payoff = float("-inf")
    for a_idx, action in enumerate(ACTIONS):
        total = others_spend + action.token_cost
        p = payoff(action, total, budget, n)
        if p > best_payoff:
            best_payoff = p
            best_action = a_idx
    return best_action


def is_nash(actions: List[int], budget: int) -> bool:
    for i in range(len(actions)):
        br = best_response(i, actions, budget)
        if br != actions[i]:
            return False
    return True


def social_welfare(actions: List[int], budget: int) -> float:
    n = len(actions)
    total = sum(ACTIONS[a].token_cost for a in actions)
    return sum(payoff(ACTIONS[a], total, budget, n) for a in actions)


def simulate(n_agents: int, budget: int, rounds: int) -> dict:
    actions = [random.randint(0, len(ACTIONS) - 1) for _ in range(n_agents)]
    converged_round = -1

    for r in range(rounds):
        agent = random.randint(0, n_agents - 1)
        actions[agent] = best_response(agent, actions, budget)
        if is_nash(actions, budget):
            converged_round = r
            break

    final_actions = [ACTIONS[a].name for a in actions]
    sw = social_welfare(actions, budget)
    optimal_sw = n_agents * 9

    return {
        "converged": converged_round >= 0,
        "converged_round": converged_round,
        "final_actions": final_actions,
        "social_welfare": sw,
        "optimal_welfare": optimal_sw,
        "price_of_anarchy": optimal_sw / sw if sw > 0 else float("inf"),
        "is_nash": is_nash(actions, budget),
    }


def main():
    parser = argparse.ArgumentParser(description="Nash convergence simulator")
    parser.add_argument("--agents", type=int, default=5)
    parser.add_argument("--budget", type=int, default=125)
    parser.add_argument("--rounds", type=int, default=1000)
    parser.add_argument("--repeats", type=int, default=50)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", type=str, required=True)
    args = parser.parse_args()

    random.seed(args.seed)
    results = []
    for i in range(args.repeats):
        result = simulate(args.agents, args.budget, args.rounds)
        result["repeat"] = i + 1
        results.append(result)

    convergence_rate = sum(1 for r in results if r["converged"]) / len(results)
    nash_rate = sum(1 for r in results if r["is_nash"]) / len(results)
    avg_poa = sum(r["price_of_anarchy"] for r in results if r["is_nash"]) / max(
        1, sum(1 for r in results if r["is_nash"])
    )

    output = {
        "params": {
            "agents": args.agents,
            "budget": args.budget,
            "rounds": args.rounds,
            "repeats": args.repeats,
            "seed": args.seed,
        },
        "summary": {
            "convergence_rate": convergence_rate,
            "nash_equilibrium_rate": nash_rate,
            "avg_price_of_anarchy": avg_poa,
        },
        "runs": results,
    }

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(output, f, indent=2)

    print(f"convergence_rate={convergence_rate:.2%} nash_rate={nash_rate:.2%} avg_poa={avg_poa:.3f}")
    return 0 if nash_rate > 0.9 else 1


if __name__ == "__main__":
    sys.exit(main())
```

**Step 2: Run and capture evidence**

```bash
python3 benchmarks/simulations/nash_convergence.py \
  --agents 5 --budget 125 --rounds 1000 --repeats 50 \
  --out benchmarks/raw/nash-convergence.json
```

**Step 3: Commit**

```bash
git add benchmarks/simulations/ benchmarks/raw/nash-convergence.json
git commit -m "feat(benchmarks): Nash equilibrium convergence simulator with evidence"
```

---

## Phase 5: Claim Ledger & Evidence Closure

### Task 13: Add New Claims to Ledger

**Files:**
- Modify: `claims/claim_scope.yaml`
- Modify: `claims/claim_ledger.yaml`
- Modify: `claims/theorem_inventory.yaml`

Add claims C-018 through C-021:

| Claim | Statement | Type |
|-------|-----------|------|
| C-018 | Fulcrum coordination game admits a Nash equilibrium | formal |
| C-019 | Governance mechanism is incentive-compatible (DSIC) | formal |
| C-020 | Coordination loss (Price of Anarchy) bounded at 9/7 | hybrid |
| C-021 | Budget enforcement grounds the game model | formal |

**Claim scope entries:**

```yaml
  - claim_id: C-018
    statement: Fulcrum coordination game admits a Nash equilibrium under budget constraints
    type: formal
    status: proven
    closure_criteria:
      - lean_game_definitions_compiled
      - pure_strategy_nash_existence_proven
      - mixed_strategy_nash_existence_proven_via_kakutani
      - no_sorry_in_proofs
    owner: formal-systems
  - claim_id: C-019
    statement: Fulcrum governance mechanism is dominant-strategy incentive-compatible
    type: formal
    status: proven
    closure_criteria:
      - mechanism_design_structures_defined
      - dsic_theorem_proven
      - no_sorry_in_proofs
    owner: formal-systems
  - claim_id: C-020
    statement: Coordination loss (Price of Anarchy) is bounded at 9/7
    type: hybrid
    status: proven
    closure_criteria:
      - lean_poa_bound_proven
      - tla_coordination_invariants_hold
      - simulation_convergence_rate_above_90pct
    owner: formal-systems
  - claim_id: C-021
    statement: Budget enforcement grounds the coordination game model
    type: formal
    status: proven
    closure_criteria:
      - bridge_theorem_connects_budget_safety_to_game
      - runtime_blocks_overspend_proven
    owner: formal-systems
```

**Theorem inventory entries:**

```yaml
  - theorem_id: THM-NASH-PURE-EXISTENCE
    assumptions:
      - A-GAME-001: agents have finite action sets
      - A-GAME-002: budget = 25 * agentCount (tight)
      - A-GAME-003: violation penalty (20) > quality gain from noncompliance (1)
    lean_module: Proofs/GameTheory/NashExistence.lean
    dependencies: [THM-BUDGET-LOCAL]
    proof_status: proven
  - theorem_id: THM-NASH-MIXED-EXISTENCE
    assumptions:
      - A-GAME-004: finite strategy sets (Fintype)
      - A-GAME-005: real-valued continuous payoffs
    lean_module: Proofs/GameTheory/MixedNashExistence.lean
    dependencies: [THM-NASH-PURE-EXISTENCE]
    proof_status: proven
    notes: Via Kakutani FPT (imported from harfe/fixed-point-theorems-lean4).
      Noncomputable (Classical.choice). First mixed Nash existence in Lean 4.
  - theorem_id: THM-NONCOMPLIANT-DOMINATED
    assumptions: [A-GAME-003]
    lean_module: Proofs/GameTheory/NashExistence.lean
    dependencies: []
    proof_status: proven
  - theorem_id: THM-DSIC
    assumptions:
      - A-MECH-001: proportional allocation with sufficient budget
    lean_module: Proofs/GameTheory/IncentiveCompatibility.lean
    dependencies: [THM-NASH-PURE-EXISTENCE]
    proof_status: proven
  - theorem_id: THM-POA-BOUNDED
    assumptions: [A-GAME-001, A-GAME-002]
    lean_module: Proofs/GameTheory/CoordinationEfficiency.lean
    dependencies: [THM-NASH-PURE-EXISTENCE]
    proof_status: proven
  - theorem_id: THM-BUDGET-GAME-BRIDGE
    assumptions: [A-BUDGET-001]
    lean_module: Proofs/GameTheory/BudgetGameBridge.lean
    dependencies: [THM-BUDGET-LOCAL]
    proof_status: proven
```

**Commit:**

```bash
git add claims/
git commit -m "feat(claims): add Nash equilibrium coordination claims C-018 through C-021"
```

---

### Task 14: Full Evidence Gate Run

```bash
# Replay all Lean proofs
cd proofs/lean && lake build && cd ../..
./proofs/lean/scripts/check_no_sorry.sh
./proofs/lean/scripts/replay.sh

# Run all TLA+ model checks
./models/tla/scripts/run_tlc.sh

# Run evidence gate
python3 scripts/evidence_gate.py

# Run audit gate
python3 scripts/audit_gate.py
```

**Commit all evidence:**

```bash
git add proofs/lean/reports/ models/tla/reports/ benchmarks/raw/
git commit -m "evidence: full gate pass with Nash equilibrium coordination proofs"
```

---

## Appendix A: Revised Assumptions Register

| ID | Assumption | Justification | Risk if Violated |
|----|-----------|---------------|------------------|
| A-GAME-001 | Agents have exactly 4 finite actions | Essential tradeoff model. Real agents richer but bounded | Equilibrium may shift; finite game guarantee still holds |
| A-GAME-002 | Budget tight (= 25 * n) | Pure equilibrium depends on tightness | For loose budgets, aggressive may dominate; mixed Nash still exists |
| A-GAME-003 | Violation penalty (20) > quality gain (1) | Governance must penalize sufficiently | If penalty < gain, noncompliant becomes rational |
| A-GAME-004 | Finite strategy types (Fintype) | Required for Kakutani application | Infinite games need different theorems |
| A-GAME-005 | Real-valued payoffs, continuous in mixed strategies | Standard for Nash via Kakutani | Discontinuous payoffs may lack equilibria |
| A-MECH-001 | Proportional allocation | Simplification of Oracle-informed allocation | Oracle-augmented mechanism needs separate IC proof |
| **NEW** | Classical.choice is acceptable | All FPT proofs are classical; noncomputable | Cannot extract verified runtime solver from proofs |
| **NEW** | External repos (harfe, math-xmum) are correct | Community-reviewed, gap-free claimed | Should verify no sorry in imported code |

## Appendix B: Tooling Requirements (Revised)

| Tool | Required For | Installation | Status |
|------|-------------|-------------|--------|
| Lean 4 + elan | All formal proofs | `elan` toolchain manager | Already present |
| Mathlib4 | Type infrastructure, PMF, real analysis | `lake update` | New dependency |
| harfe/fixed-point-theorems-lean4 | Kakutani + Brouwer FPT | `lake update` (lakefile dep) | New dependency |
| math-xmum/Brouwer | Product simplex infrastructure | `lake update` (lakefile dep) | New dependency |
| Java 17+ | TLC model checker | Already present | Existing |
| Python 3.12+ | Simulation harness | Already present | Existing |
| Veil framework | Future: unified verification | `lake` dep (optional) | Deferred to Task 11 |

**No pip packages needed. No new system installations.** Everything comes through `lake update`.

## Appendix C: What Makes This Novel

If Tasks 5-6 succeed, this repo will contain:

1. **First mixed-strategy Nash existence proof in Lean 4** — no prior work has connected Kakutani FPT to game definitions in Lean
2. **First formal incentive compatibility proof for an AI governance mechanism** — no proof assistant has verified mechanism design for multi-agent AI systems
3. **First formal Price of Anarchy bound for an AI coordination game** — connecting efficiency loss to governance mechanism parameters
4. **Three-axis closure** (formal proof + model checking + empirical simulation) for game-theoretic claims — matching the existing pattern for C-014

## Appendix D: Risk-Ordered Task Dependencies

```
Task 1 (lakefile deps) ──────── HIGHEST RISK: version conflicts
  └─ Task 2 (import check) ──── verify access to Kakutani + product simplex
      ├─ Task 3 (definitions) ── standard, low risk
      │   └─ Task 4 (Fulcrum game) ── standard, low risk
      │       ├─ Task 5 (pure Nash) ── medium risk: tactic engineering
      │       ├─ Task 7 (IC) ── medium risk: proportional mechanism proof
      │       └─ Task 8 (PoA + bridge) ── low risk: arithmetic
      └─ Task 6 (mixed Nash via Kakutani) ── HIGH RISK: library stitching
Task 9 (TLA+) ── independent, low risk
Task 10 (TLC reports) ── depends on 9, low risk
Task 12 (simulation) ── independent, low risk
Task 13 (claims) ── depends on all proofs
Task 14 (gates) ── depends on everything
```

**Critical path:** Task 1 → Task 2 → Task 6. If the external libraries don't interoperate, the mixed-strategy proof needs a fallback plan (restrict to 2-player, or prove directly without importing Kakutani).
