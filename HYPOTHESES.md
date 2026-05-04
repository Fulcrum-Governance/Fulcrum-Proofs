# Hypotheses Register

This file documents the major non-axiom assumptions that shape the theorem
statements in Fulcrum-Proofs today.

These are not hidden caveats. They are the bounded, explicit hypotheses under
which the current formal and empirical claims are stated. The deployment-axiom
surface itself is tracked separately in `proofs/lean/expected_axioms.md`.

## Tight budget regime

**Where it appears**

- `A-GAME-002` in `claims/theorem_inventory.yaml`
- `Fulcrum.GameTheory.fulcrum_pure_nash_exists`
- `Fulcrum.GameTheory.nash_eq_allModerate`
- `Fulcrum.GameTheory.fulcrum_poa_bounded`
- `Fulcrum.GameTheory.constrained_welfare_optimal`
- `Fulcrum.GameTheory.constrained_poa_exact`

**Why this is a hypothesis instead of an axiom**

The current game-theory results are about the audited policy regime
`totalBudget = 25 * agentCount`. That is a theorem precondition on the modeled
system, not an unproved kernel assumption.

**What would relax it**

A more general budget-sensitive proof that ranges over arbitrary budget ratios,
or a new family of theorems parameterized by budget slack rather than the
current tight-budget equality.

## Small-agent bound (`agentCount ≤ 12`)

**Where it appears**

- `Fulcrum.GameTheory.nash_eq_allModerate`
- `Fulcrum.GameTheory.constrained_welfare_optimal`
- `Fulcrum.GameTheory.constrained_poa_exact`

**Why this is a hypothesis instead of an axiom**

The current closure uses a bounded combinatorial argument aligned with the
audited deployment regime and the exhaustive `n = 2..12` evidence pack.

**What would relax it**

A proof that removes the bounded elimination step, or a new asymptotic argument
that replaces the current `n ≤ 12` case structure with a parameter-free proof.

## Finite strategy sets and continuous payoffs

**Where it appears**

- `A-GAME-004` and `A-GAME-005` in `claims/theorem_inventory.yaml`
- `Fulcrum.GameTheory.mixed_nash_exists`

**Why this is a hypothesis instead of an axiom**

Mixed Nash existence is proved through the vendored Brouwer/Scarf route, which
is stated for finite games with continuous real-valued payoffs.

**What would relax it**

A different equilibrium-existence theorem for a broader class of games, or a
new bridge from the current PMF model into a more general compact strategy
space.

## Utility model for the DSIC counterexample

**Where it appears**

- `A-MECH-001` in `claims/theorem_inventory.yaml`
- `Fulcrum.GameTheory.proportional_allocation_not_dsic`

**Why this is a hypothesis instead of an axiom**

The negative DSIC result is about the current utility model
`allocationUtility = -|allocation - trueNeed|`. Changing the utility model
changes the theorem statement itself.

**What would relax it**

A different allocation objective, a different mechanism, or a proof over a
family of utility functions rather than the current audited one.

## Temporal capability and revocation semantics

**Where it appears**

- `A-TEMP-001` through `A-TEMP-005` in `claims/theorem_inventory.yaml`
- `Fulcrum.thm_temporal_conservation_spec`
- `Fulcrum.thm_temporal_revocation_fail_closed`

**Why this is a hypothesis instead of an axiom**

These theorems formalize a specific gateway semantics: stable requested
capabilities, monotone available capabilities, per-hop revalidation, epoch
monotonicity, and revocation stickiness.

**What would relax it**

A richer transition system that models capability mutation explicitly and then
proves conservation or fail-closed behavior for that larger state machine.

## Trust-threshold well-formedness

**Where it appears**

- `A-TRUST-003` and `A-TRUST-004` in `claims/theorem_inventory.yaml`
- `Fulcrum.trust_threshold_reachable`
- `Fulcrum.trust_termination_invariant`
- `Fulcrum.trust_guaranteed_termination`

**Why this is a hypothesis instead of an axiom**

The trust proofs are about well-formed thresholded circuit-breaker states and a
rational threshold `p / q` with `0 < p < q`. Those are theorem inputs, not
external kernel assumptions.

**What would relax it**

A proof that starts from a raw transition relation and derives well-formedness
as an invariant, or an alternate trust parametrization that generalizes beyond
the current Beta-mean threshold model.

## RLM state invariants and step semantics

**Where it appears**

- `A-RLM-001` through `A-RLM-004` in `claims/theorem_inventory.yaml`
- `Fulcrum.RLM.rlm_depth_bounded`
- `Fulcrum.RLM.rlm_step_decreases_measure`
- `Fulcrum.RLM.rlm_answer_monotone`
- `Fulcrum.RLM.rlm_token_budget_respected`

**Why this is a hypothesis instead of an axiom**

These theorems reason over a deliberately small interface model: state carries
depth, partition count, and token budget invariants, and the step function
processes one partition at a time.

**What would relax it**

An enriched operational semantics for the full inference loop, including more
of the runtime state and concurrency behavior. The deployment boundary itself
remains separately tracked as the `canAccess` / `context_partition_isolation`
axiom pair.
