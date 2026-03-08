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
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple


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


def action_count_profiles(total_agents: int, action_count: int) -> Iterable[Tuple[int, ...]]:
    if action_count == 1:
        yield (total_agents,)
        return
    for count in range(total_agents + 1):
        for rest in action_count_profiles(total_agents - count, action_count - 1):
            yield (count,) + rest


def optimal_welfare(n_agents: int, budget: int) -> float:
    """Compute the welfare optimum under the same budgeted payoff model.

    Because payoff depends only on total spend and action counts, we can search
    over action-count compositions instead of enumerating every agent profile.
    """
    best = float("-inf")
    for counts in action_count_profiles(n_agents, len(ACTIONS)):
        total = sum(count * action.token_cost for count, action in zip(counts, ACTIONS))
        welfare = sum(count * payoff(action, total, budget, n_agents) for count, action in zip(counts, ACTIONS))
        if welfare > best:
            best = welfare
    return best


def simulate(n_agents: int, budget: int, rounds: int, optimal_sw: float) -> dict:
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
    optimal_sw = optimal_welfare(args.agents, args.budget)
    results = []
    for i in range(args.repeats):
        result = simulate(args.agents, args.budget, args.rounds, optimal_sw)
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
