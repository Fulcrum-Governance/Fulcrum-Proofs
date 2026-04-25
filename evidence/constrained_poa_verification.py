#!/usr/bin/env python3
"""Verify constrained PoA for the Fulcrum tight-budget coordination game.

Under B = 25n, cost and welfare depend only on action counts, so enumerating
count triples is exhaustive up to profile permutation.
"""

import json
from datetime import datetime, timezone


def main() -> None:
    results = []
    for n in range(2, 13):
        budget = 25 * n
        best_welfare = 0
        best_profile = ""
        count_vectors_checked = 0

        for k_agg in range(n + 1):
            for k_mod in range(n - k_agg + 1):
                k_con = n - k_agg - k_mod
                total_cost = 50 * k_agg + 25 * k_mod + 10 * k_con
                count_vectors_checked += 1
                if total_cost <= budget:
                    welfare = 9 * k_agg + 7 * k_mod + 3 * k_con
                    if welfare > best_welfare:
                        best_welfare = welfare
                        best_profile = (
                            f"agg={k_agg},mod={k_mod},con={k_con},cost={total_cost}"
                        )

        all_moderate_welfare = 7 * n
        constrained_poa = best_welfare / all_moderate_welfare
        result = {
            "n": n,
            "budget": budget,
            "best_feasible_welfare": best_welfare,
            "best_profile": best_profile,
            "all_moderate_welfare": all_moderate_welfare,
            "constrained_poa": constrained_poa,
            "count_vectors_checked": count_vectors_checked,
        }
        results.append(result)
        assert constrained_poa == 1.0, f"FAILED: n={n}, ratio={constrained_poa}"

    output = {
        "claim": "C-020",
        "result": "Constrained PoA = 1.0 for all n in [2, 12]",
        "verification_date": datetime.now(timezone.utc).isoformat(),
        "method": (
            "exhaustive enumeration of action-count equivalence classes for "
            "budget-feasible strategy profiles, excluding noncompliant actions"
        ),
        "details": results,
    }
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
