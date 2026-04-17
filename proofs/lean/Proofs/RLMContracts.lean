/-
  RLM Interface Contracts

  Type signatures and invariants that define correctness criteria for
  Recursive Language Model (RLM) implementations (arXiv:2512.24601).

  These are *interface contracts* — they specify what a correct RLM
  implementation must satisfy without requiring the full implementation
  to exist. An acquirer's formal methods engineer can verify that these
  contracts match the Go interfaces in internal/rlm/interfaces.go.

  Contracts proven from definitions: depth bounded, step decreasing,
  answer monotonicity. Isolation is axiomatized (sandbox property,
  not provable from pure math).

  Reference: internal/rlm/interfaces.go (Go), internal/rlm/inference/loop.go
-/

import Mathlib.Data.Nat.Basic
import Mathlib.Tactic

namespace Fulcrum.RLM

-- ═══════════════════════════════════════════════════════════════════════
-- Definitions (mirror Go internal/rlm/interfaces.go)
-- ═══════════════════════════════════════════════════════════════════════

/-- Default max recursion depth from Go: DefaultMaxRecursionDepth = 5 -/
def defaultMaxDepth : Nat := 5

/-- Execution constraints matching Go ExecutionConstraints struct. -/
structure ExecutionConstraints where
  depthLimit : Nat       -- max recursion depth
  tokenBudget : Nat      -- max tokens consumed
  outputLimitBytes : Nat  -- max output size
  h_depth_pos : 0 < depthLimit

/-- Default constraints matching Go DefaultExecutionConstraints(). -/
def defaultConstraints : ExecutionConstraints where
  depthLimit := 5
  tokenBudget := 128000
  outputLimitBytes := 65536
  h_depth_pos := by omega

/-- A context partition is a bounded slice of the full context.
    Maps to the partitioning strategy in the inference loop. -/
structure ContextPartition where
  contextId : Nat
  startPos : Nat
  endPos : Nat
  h_valid : startPos ≤ endPos

/-- RLM inference state tracking progress through context navigation. -/
structure RLMState where
  depth : Nat                 -- current recursion depth
  maxDepth : Nat              -- configured limit
  partitionsRemaining : Nat   -- unprocessed context partitions
  partitionsTotal : Nat       -- total partitions (invariant)
  tokensConsumed : Nat        -- tokens used so far
  tokenBudget : Nat           -- max tokens allowed
  answerReady : Bool          -- convergence flag
  h_depth_le : depth ≤ maxDepth
  h_parts_le : partitionsRemaining ≤ partitionsTotal

/-- An RLM state is valid when all resource constraints hold. -/
def validState (s : RLMState) : Prop :=
  s.depth ≤ s.maxDepth ∧
  s.partitionsRemaining ≤ s.partitionsTotal ∧
  s.tokensConsumed ≤ s.tokenBudget

-- ═══════════════════════════════════════════════════════════════════════
-- Contract A: Context Partition Isolation (Axiom)
-- ═══════════════════════════════════════════════════════════════════════

/-- Abstract predicate: can a sub-instance at the given depth
    access data at the given position? -/
axiom canAccess : Nat → ContextPartition → Nat → Prop

/-- Contract: sub-instances can only access data within their assigned
    partition boundaries. This is a specification of what the Docker
    sandbox (internal/rlm/sandbox/docker.go) must enforce.

    This is axiomatized because it's a systems property of the container
    configuration, not a mathematical property. Any correct sandbox
    implementation must satisfy this contract. -/
axiom context_partition_isolation :
  ∀ (depth : Nat) (p : ContextPartition) (pos : Nat),
    canAccess depth p pos → p.startPos ≤ pos ∧ pos ≤ p.endPos

-- ═══════════════════════════════════════════════════════════════════════
-- Step Function
-- ═══════════════════════════════════════════════════════════════════════

/-- A single inference step: process one partition, consuming tokens.
    Returns None if no partitions remain or answer is already ready.
    Models the core loop body in internal/rlm/inference/loop.go. -/
def rlmStep (s : RLMState) (tokensUsed : Nat)
    (_h_tokens : tokensUsed > 0) : Option RLMState :=
  if s.answerReady then
    none
  else if h_parts : s.partitionsRemaining = 0 then
    none
  else if _h_budget : s.tokensConsumed + tokensUsed > s.tokenBudget then
    none
  else
    have _h_parts_pos : 0 < s.partitionsRemaining := Nat.pos_of_ne_zero h_parts
    have h_new_parts_le : s.partitionsRemaining - 1 ≤ s.partitionsTotal :=
      Nat.le_trans (Nat.sub_le s.partitionsRemaining 1) s.h_parts_le
    some {
      depth := s.depth
      maxDepth := s.maxDepth
      partitionsRemaining := s.partitionsRemaining - 1
      partitionsTotal := s.partitionsTotal
      tokensConsumed := s.tokensConsumed + tokensUsed
      tokenBudget := s.tokenBudget
      answerReady := s.partitionsRemaining - 1 = 0  -- ready when last partition processed
      h_depth_le := s.h_depth_le
      h_parts_le := h_new_parts_le
    }

-- ═══════════════════════════════════════════════════════════════════════
-- Contract B: Bounded Recursion Depth
-- ═══════════════════════════════════════════════════════════════════════

/-- The recursion depth never exceeds the configured maximum.
    This is trivially true from the RLMState structure invariant,
    but we state it as a theorem for the contract inventory. -/
theorem rlm_depth_bounded (s : RLMState) :
    s.depth ≤ s.maxDepth :=
  s.h_depth_le

/-- After a step, depth is still bounded. -/
theorem rlm_step_preserves_depth (s : RLMState) (tok : Nat) (htok : tok > 0)
    (s' : RLMState) (h_step : rlmStep s tok htok = some s') :
    s'.depth ≤ s'.maxDepth := by
  unfold rlmStep at h_step
  by_cases h_ready : s.answerReady = true
  · simp [h_ready] at h_step
  · by_cases h_parts : s.partitionsRemaining = 0
    · simp [h_ready, h_parts] at h_step
    · by_cases h_budget : s.tokensConsumed + tok > s.tokenBudget
      · simp [h_ready, h_parts, h_budget] at h_step
      · simp [h_ready, h_parts, h_budget] at h_step
        obtain rfl := h_step
        exact s.h_depth_le

-- ═══════════════════════════════════════════════════════════════════════
-- Contract C: Termination Measure (Step Decreasing)
-- ═══════════════════════════════════════════════════════════════════════

/-- Termination measure: number of unprocessed partitions. -/
def terminationMeasure (s : RLMState) : Nat := s.partitionsRemaining

/-- Each successful step strictly decreases the termination measure.
    This establishes well-founded recursion for the inference loop:
    the loop must terminate in at most partitionsTotal steps. -/
theorem rlm_step_decreases_measure (s : RLMState) (tok : Nat) (htok : tok > 0)
    (s' : RLMState) (h_step : rlmStep s tok htok = some s') :
    terminationMeasure s' < terminationMeasure s := by
  unfold rlmStep at h_step
  by_cases h_ready : s.answerReady = true
  · simp [h_ready] at h_step
  · by_cases h_parts : s.partitionsRemaining = 0
    · simp [h_ready, h_parts] at h_step
    · by_cases h_budget : s.tokensConsumed + tok > s.tokenBudget
      · simp [h_ready, h_parts, h_budget] at h_step
      · simp [h_ready, h_parts, h_budget] at h_step
        obtain rfl := h_step
        unfold terminationMeasure
        exact Nat.sub_lt (Nat.pos_of_ne_zero h_parts) Nat.zero_lt_one

/-- The loop terminates in at most partitionsTotal iterations. -/
theorem rlm_bounded_iterations (s : RLMState) :
    terminationMeasure s ≤ s.partitionsTotal :=
  s.h_parts_le

-- ═══════════════════════════════════════════════════════════════════════
-- Contract D: Answer Readiness Monotonicity
-- ═══════════════════════════════════════════════════════════════════════

/-- Once answerReady is true, the step function returns None (no further
    state transitions). This means answer readiness is monotonic:
    once an answer is produced, it cannot be retracted. -/
theorem rlm_answer_monotone (s : RLMState) (tok : Nat) (htok : tok > 0)
    (h_ready : s.answerReady = true) :
    rlmStep s tok htok = none := by
  unfold rlmStep
  simp [h_ready]

/-- The step function only produces a ready answer when the last
    partition has been processed. -/
theorem rlm_answer_on_completion (s : RLMState) (tok : Nat) (htok : tok > 0)
    (s' : RLMState) (h_step : rlmStep s tok htok = some s')
    (h_ready : s'.answerReady = true) :
    s'.partitionsRemaining = 0 := by
  unfold rlmStep at h_step
  by_cases h_state_ready : s.answerReady = true
  · simp [h_state_ready] at h_step
  · by_cases h_parts : s.partitionsRemaining = 0
    · simp [h_state_ready, h_parts] at h_step
    · by_cases h_budget : s.tokensConsumed + tok > s.tokenBudget
      · simp [h_state_ready, h_parts, h_budget] at h_step
      · simp [h_state_ready, h_parts, h_budget] at h_step
        obtain rfl := h_step
        simpa using h_ready

-- ═══════════════════════════════════════════════════════════════════════
-- Contract E: Token Budget Enforcement
-- ═══════════════════════════════════════════════════════════════════════

/-- The step function refuses to proceed if the token budget would be
    exceeded. No step can cause token consumption to exceed the budget. -/
theorem rlm_token_budget_respected (s : RLMState) (tok : Nat) (htok : tok > 0)
    (s' : RLMState) (h_step : rlmStep s tok htok = some s') :
    s'.tokensConsumed ≤ s'.tokenBudget := by
  unfold rlmStep at h_step
  by_cases h_ready : s.answerReady = true
  · simp [h_ready] at h_step
  · by_cases h_parts : s.partitionsRemaining = 0
    · simp [h_ready, h_parts] at h_step
    · by_cases h_budget : s.tokensConsumed + tok > s.tokenBudget
      · simp [h_ready, h_parts, h_budget] at h_step
      · simp [h_ready, h_parts, h_budget] at h_step
        obtain rfl := h_step
        exact le_of_not_gt h_budget

end Fulcrum.RLM
