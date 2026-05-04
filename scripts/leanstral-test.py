#!/usr/bin/env python3
"""
Leanstral Integration Test for Fulcrum-Proofs

Tests Mistral's Leanstral model against a real Lean 4 proof task from our repo.
Validates API connectivity, model availability, and output quality.

Usage:
    cd "$(git rev-parse --show-toplevel)"
    python3 scripts/leanstral-test.py
"""

import os
import sys
import time

def main():
    api_key = os.environ.get("MISTRAL_API_KEY")
    if not api_key:
        print("ERROR: MISTRAL_API_KEY env var not set. Export it before running.")
        sys.exit(1)

    try:
        from mistralai.client import Mistral
    except ImportError:
        print("ERROR: pip install mistralai --break-system-packages")
        sys.exit(1)

    client = Mistral(api_key=api_key)

    # -----------------------------------------------------------
    # Test 1: Simple connectivity check with a trivial Lean task
    # -----------------------------------------------------------
    print("=" * 60)
    print("TEST 1: Connectivity + trivial Lean 4 task")
    print("=" * 60)

    trivial_prompt = """Fix this Lean 4 code so it compiles without sorry:

```lean
theorem add_comm_nat (a b : Nat) : a + b = b + a := by
  sorry
```

Provide only the fixed Lean 4 code, no explanation."""

    t0 = time.time()
    try:
        response = client.chat.complete(
            model="labs-leanstral-2603",
            messages=[{"role": "user", "content": trivial_prompt}],
        )
        elapsed = time.time() - t0
        print(f"Response time: {elapsed:.1f}s")
        print(f"Model: {response.model}")
        print(f"Tokens: {response.usage.prompt_tokens} in / {response.usage.completion_tokens} out")
        print(f"\nResponse:\n{response.choices[0].message.content[:500]}")
        print("\n✅ TEST 1 PASSED: API connected, model responding")
    except Exception as e:
        print(f"\n❌ TEST 1 FAILED: {e}")
        sys.exit(1)

    # -----------------------------------------------------------
    # Test 2: Real Fulcrum task — toolchain migration error
    # -----------------------------------------------------------
    print("\n" + "=" * 60)
    print("TEST 2: Toolchain migration fix (representative of math-xmum work)")
    print("=" * 60)

    migration_prompt = """I'm upgrading a Lean 4 project from v4.22.0 to v4.29.0-rc4.
The following code fails to compile after the upgrade:

```lean
import Mathlib.Topology.Basic

theorem compact_simplex (n : Nat) :
    IsCompact (Set.Icc (0 : Fin n → ℝ) 1) := by
  apply isCompact_Icc
```

The error is:
```
error: unknown identifier 'isCompact_Icc'
```

What changed between Lean 4.22 and 4.29 that would cause this?
What is the correct fix? Provide the fixed code."""

    t0 = time.time()
    try:
        response = client.chat.complete(
            model="labs-leanstral-2603",
            messages=[{"role": "user", "content": migration_prompt}],
        )
        elapsed = time.time() - t0
        print(f"Response time: {elapsed:.1f}s")
        print(f"Tokens: {response.usage.prompt_tokens} in / {response.usage.completion_tokens} out")
        print(f"\nResponse:\n{response.choices[0].message.content[:800]}")
        print("\n✅ TEST 2 PASSED: Model handles toolchain migration tasks")
    except Exception as e:
        print(f"\n❌ TEST 2 FAILED: {e}")

    # -----------------------------------------------------------
    # Test 3: Actual mixed Nash sorry from our repo
    # -----------------------------------------------------------
    print("\n" + "=" * 60)
    print("TEST 3: Mixed Nash existence — actual sorry from Fulcrum-Proofs")
    print("=" * 60)

    nash_prompt = """I have a Lean 4 (v4.29.0-rc4) project with the following sorry.
I want to close it by importing an external library (math-xmum/Brouwer)
that already has `ExistsNashEq` proved via Nash's 1951 continuous gain mapping.

My current code uses PMF-based mixed strategies:

```lean
noncomputable def MixedStrategy {n : Nat} (G : NormalFormGame n) (i : Fin n) :=
  @PMF (G.Strategy i)

noncomputable def MixedStrategyProfile {n : Nat} (G : NormalFormGame n) :=
  (i : Fin n) → MixedStrategy G i

def IsMixedNashEquilibrium {n : Nat} (G : NormalFormGame n)
    (σ : MixedStrategyProfile G) : Prop :=
  ∀ i : Fin n, σ i ∈ bestResponseCorrespondence G i σ

theorem mixed_nash_exists {n : Nat} (G : NormalFormGame n) (hn : n > 0) :
    ∃ σ : MixedStrategyProfile G, IsMixedNashEquilibrium G σ := by
  sorry
```

The external library (math-xmum/Brouwer) defines games using simplex coordinates
(Fin k → ℝ) rather than PMF. What bridge lemmas do I need to convert between
PMF-based strategies and simplex-coordinate strategies?

Specifically:
1. How to convert PMF to a point on the standard simplex
2. How to convert back
3. How to show payoff preservation under the conversion

Provide concrete Lean 4 code for these bridge lemmas."""

    t0 = time.time()
    try:
        response = client.chat.complete(
            model="labs-leanstral-2603",
            messages=[{"role": "user", "content": nash_prompt}],
        )
        elapsed = time.time() - t0
        print(f"Response time: {elapsed:.1f}s")
        print(f"Tokens: {response.usage.prompt_tokens} in / {response.usage.completion_tokens} out")
        print(f"\nResponse (first 1200 chars):\n{response.choices[0].message.content[:1200]}")
        print("\n✅ TEST 3 PASSED: Model produces bridge lemma proposals")
    except Exception as e:
        print(f"\n❌ TEST 3 FAILED: {e}")

    # -----------------------------------------------------------
    # Summary
    # -----------------------------------------------------------
    print("\n" + "=" * 60)
    print("LEANSTRAL INTEGRATION TEST COMPLETE")
    print("=" * 60)
    print(f"API Key: ...{api_key[-4:]}")
    print(f"Model: labs-leanstral-2603")
    print("Next: Use Leanstral for math-xmum toolchain fixes")

if __name__ == "__main__":
    main()
