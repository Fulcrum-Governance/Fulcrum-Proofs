/-
  Structural uniqueness of the exact pure Nash equilibrium.

  The proof is uniform for every positive roster through twelve.  It reasons
  with structural action counts and subtraction-free natural-number identities;
  it never enumerates a roster size or a strategy profile.
-/

import Proofs.GameTheory.ExactNashExistence

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- The exact Nash condition specialized to a unilateral moderate deviation. -/
theorem exactNash_moderate_deviation_bound (params : BudgetParams)
    (profile : ExactProfile params.agentCount)
    (hNash : ExactIsNash params profile)
    (i : Fin params.agentCount) (action : AgentAction)
    (hi : profile i = action) :
    params.agentCount * 7 +
        (params.agentCount * exactActionPenalty action + exactOverflow params profile) ≤
      params.agentCount * exactActionQuality action +
        exactOverflow params (exactUpdate profile i .moderate) := by
  have h := hNash i AgentAction.moderate
  simp only [exactPayoffNumerator, exactUpdate_same, hi] at h
  change params.agentCount * exactActionQuality AgentAction.moderate +
      (params.agentCount * exactActionPenalty action + exactOverflow params profile) ≤
    params.agentCount * exactActionQuality action +
      (params.agentCount * exactActionPenalty AgentAction.moderate +
        exactOverflow params (exactUpdate profile i .moderate)) at h
  simpa [exactActionQuality, exactActionPenalty, exactActionViolates] using h

/-- A noncompliant-to-moderate deviation lowers the structural token total by fifteen. -/
theorem exactNoncompliant_moderate_total (params : BudgetParams)
    (profile : ExactProfile params.agentCount) (i : Fin params.agentCount)
    (hi : profile i = AgentAction.noncompliant) :
    exactTotalTokens (exactUpdate profile i .moderate) + 15 =
      exactTotalTokens profile := by
  have h := exactTotalTokens_update_general profile i AgentAction.moderate
  rw [hi] at h
  change exactTotalTokens (exactUpdate profile i .moderate) + 40 =
    exactTotalTokens profile + 25 at h
  change (exactTotalTokens (exactUpdate profile i .moderate) + 15) + 25 =
    exactTotalTokens profile + 25 at h
  exact Nat.add_right_cancel h

/-- No exact pure Nash profile contains a noncompliant action. -/
theorem exactNoNoncompliant_inNash (params : BudgetParams)
    (profile : ExactProfile params.agentCount)
    (hNash : ExactIsNash params profile) :
    ∀ i, profile i ≠ AgentAction.noncompliant := by
  intro i hi
  have hTotal := exactNoncompliant_moderate_total params profile i hi
  have hTotalLe : exactTotalTokens (exactUpdate profile i .moderate) ≤
      exactTotalTokens profile := by
    rw [← hTotal]
    exact Nat.le_add_right _ _
  have hOverflow := exactOverflow_mono params
    (exactUpdate profile i .moderate) profile hTotalLe
  have hPay := exactNash_moderate_deviation_bound params profile hNash i
    AgentAction.noncompliant hi
  simp [exactActionPenalty, exactActionViolates, exactViolationPenalty,
    exactActionQuality] at hPay
  have hPay' : params.agentCount * 27 + exactOverflow params profile ≤
      params.agentCount * 8 +
        exactOverflow params (exactUpdate profile i .moderate) := by
    rw [← Nat.add_assoc] at hPay
    have hCombine : params.agentCount * 7 + params.agentCount * 20 =
        params.agentCount * 27 := by
      calc
        params.agentCount * 7 + params.agentCount * 20 =
            params.agentCount * (7 + 20) := (Nat.mul_add _ _ _).symm
        _ = params.agentCount * 27 := rfl
    rw [hCombine] at hPay
    exact hPay
  have hUpper : params.agentCount * 8 +
        exactOverflow params (exactUpdate profile i .moderate) ≤
      params.agentCount * 8 + exactOverflow params profile :=
    Nat.add_le_add_left hOverflow _
  have hCancel : params.agentCount * 27 ≤ params.agentCount * 8 :=
    Nat.le_of_add_le_add_right (le_trans hPay' hUpper)
  have hStrict : params.agentCount * 8 < params.agentCount * 27 :=
    Nat.mul_lt_mul_of_pos_left (by decide) params.hPositive
  exact (Nat.not_lt_of_ge hCancel hStrict).elim

/-- An aggressive-to-moderate deviation lowers the structural token total by twenty-five. -/
theorem exactAggressive_moderate_total (params : BudgetParams)
    (profile : ExactProfile params.agentCount) (i : Fin params.agentCount)
    (hi : profile i = AgentAction.aggressive) :
    exactTotalTokens (exactUpdate profile i .moderate) + 25 =
      exactTotalTokens profile := by
  have h := exactTotalTokens_update_general profile i AgentAction.moderate
  rw [hi] at h
  change exactTotalTokens (exactUpdate profile i .moderate) + 50 =
    exactTotalTokens profile + 25 at h
  change (exactTotalTokens (exactUpdate profile i .moderate) + 25) + 25 =
    exactTotalTokens profile + 25 at h
  exact Nat.add_right_cancel h

/-- A conservative-to-moderate deviation raises the structural token total by fifteen. -/
theorem exactConservative_moderate_total (params : BudgetParams)
    (profile : ExactProfile params.agentCount) (i : Fin params.agentCount)
    (hi : profile i = AgentAction.conservative) :
    exactTotalTokens (exactUpdate profile i .moderate) =
      exactTotalTokens profile + 15 := by
  have h := exactTotalTokens_update_general profile i AgentAction.moderate
  rw [hi] at h
  change exactTotalTokens (exactUpdate profile i .moderate) + 10 =
    exactTotalTokens profile + 25 at h
  change exactTotalTokens (exactUpdate profile i .moderate) + 10 =
    (exactTotalTokens profile + 15) + 10 at h
  exact Nat.add_right_cancel h

/-- Through twelve agents, the aggressive deviation bound is strict. -/
theorem exactAggressive_deviation_strict {n : Nat} (hSmall : n ≤ 12) :
    9 * n < 7 * n + 25 := by
  have hTwo : 2 * n ≤ 2 * 12 := Nat.mul_le_mul_left 2 hSmall
  have hTwentyFive : 2 * n < 25 := lt_of_le_of_lt hTwo (by decide)
  have hAdd := Nat.add_lt_add_left hTwentyFive (7 * n)
  rw [← Nat.add_mul] at hAdd
  exact hAdd

/-- A small structural count system forced by an overflow Nash profile is inconsistent. -/
theorem exactOverflow_count_contradiction
    (n aggressive conservative moderate overflow : Nat)
    (hAggressive : 0 < aggressive) (hConservative : 0 < conservative)
    (hCount : aggressive + conservative ≤ n) (hSmall : n ≤ 3)
    (hOverflow : overflow ≤ 2 * n)
    (hBalance : overflow + 15 * conservative = 25 * aggressive) : False := by
  have hOverflowSix : overflow ≤ 6 :=
    le_trans hOverflow (by
      have h := Nat.mul_le_mul_left 2 hSmall
      change 2 * n ≤ 6 at h
      exact h)
  have hConservativeTwo : conservative ≤ 2 := by
    have hOne : 1 ≤ aggressive := hAggressive
    have hStep : 1 + conservative ≤ aggressive + conservative :=
      Nat.add_le_add_right hOne conservative
    have hThree : 1 + conservative ≤ 3 :=
      le_trans hStep (le_trans hCount hSmall)
    have hThree' : conservative + 1 ≤ 2 + 1 := by
      rw [Nat.add_comm conservative 1]
      exact hThree
    exact Nat.le_of_add_le_add_right hThree'
  have hAggressiveProduct : 25 * aggressive ≤ 36 := by
    rw [← hBalance]
    have hConsProduct : 15 * conservative ≤ 30 := by
      have h := Nat.mul_le_mul_left 15 hConservativeTwo
      change 15 * conservative ≤ 30 at h
      exact h
    have h := Nat.add_le_add hOverflowSix hConsProduct
    change overflow + 15 * conservative ≤ 36 at h
    exact h
  have hAggressiveOne : aggressive ≤ 1 := by
    by_cases hTwo : 2 ≤ aggressive
    · have hFifty : 50 ≤ 25 * aggressive := by
        have h := Nat.mul_le_mul_left 25 hTwo
        change 50 ≤ 25 * aggressive at h
        exact h
      have hImpossible : 50 ≤ 36 := le_trans hFifty hAggressiveProduct
      exact False.elim ((by decide : ¬ (50 : Nat) ≤ 36) hImpossible)
    · exact Nat.lt_succ_iff.mp (Nat.lt_of_not_ge hTwo)
  have hAggressiveEq : aggressive = 1 :=
    Nat.le_antisymm hAggressiveOne hAggressive
  have hConservativeAtLeastTwo : 2 ≤ conservative := by
    by_cases hTwo : 2 ≤ conservative
    · exact hTwo
    · have hConsOne : conservative ≤ 1 :=
        Nat.lt_succ_iff.mp (Nat.lt_of_not_ge hTwo)
      have hConsProduct : 15 * conservative ≤ 15 := by
        have h := Nat.mul_le_mul_left 15 hConsOne
        change 15 * conservative ≤ 15 at h
        exact h
      have hLeft : overflow + 15 * conservative ≤ 21 := by
        have h := Nat.add_le_add hOverflowSix hConsProduct
        change overflow + 15 * conservative ≤ 21 at h
        exact h
      rw [hBalance, hAggressiveEq] at hLeft
      exact False.elim ((by decide : ¬ (25 : Nat) ≤ 21) hLeft)
  have hConservativeEq : conservative = 2 :=
    Nat.le_antisymm hConservativeTwo hConservativeAtLeastTwo
  rw [hAggressiveEq, hConservativeEq] at hBalance
  have hThirty : 30 ≤ overflow + 30 := Nat.le_add_left _ _
  rw [hBalance] at hThirty
  exact (by decide : ¬ (30 : Nat) ≤ 25) hThirty

/-- Every exact Nash profile under the tight budget has no overflow. -/
theorem exactNoOverflow_inNash (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12)
    (profile : ExactProfile params.agentCount)
    (hNash : ExactIsNash params profile)
    (hNoNC : ∀ i, profile i ≠ AgentAction.noncompliant) :
    exactTotalTokens profile ≤ params.totalBudget := by
  by_cases hWithin : exactTotalTokens profile ≤ params.totalBudget
  · exact hWithin
  · have hOverflowTotal : params.totalBudget < exactTotalTokens profile :=
      Nat.lt_of_not_ge hWithin
    have hBalance := exactTotalTokens_balance_no_noncompliant profile hNoNC
    have hNCZero : exactActionCount .noncompliant profile = 0 :=
      exactActionCount_eq_zero_of_forall_ne .noncompliant profile hNoNC
    have hPartition := exactActionCount_partition profile
    rw [hNCZero, Nat.add_zero] at hPartition
    have hAggressivePositive : 0 < exactActionCount .aggressive profile := by
      by_cases hPositive : 0 < exactActionCount .aggressive profile
      · exact hPositive
      · have hAggressiveEq : exactActionCount .aggressive profile = 0 :=
          Nat.eq_zero_of_not_pos hPositive
        rw [hAggressiveEq, Nat.mul_zero, Nat.add_zero] at hBalance
        have hTotalLe : exactTotalTokens profile ≤ 25 * params.agentCount := by
          rw [← hBalance]
          exact Nat.le_add_right _ _
        rw [← hBudget] at hTotalLe
        exact (Nat.not_lt_of_ge hTotalLe hOverflowTotal).elim
    obtain ⟨aggressiveIndex, hAggressiveAction⟩ :=
      exactActionCount_lookup_of_pos .aggressive profile hAggressivePositive
    have hAggressiveTotal := exactAggressive_moderate_total params profile
      aggressiveIndex hAggressiveAction
    have hOverflowRecovery := exactOverflow_add_budget_of_lt params profile hOverflowTotal
    have hOverflowBalance :
        exactOverflow params profile + 15 * exactActionCount .conservative profile =
          25 * exactActionCount .aggressive profile := by
      rw [← hOverflowRecovery, hBudget] at hBalance
      have hReordered : 25 * params.agentCount +
            (exactOverflow params profile + 15 * exactActionCount .conservative profile) =
          25 * params.agentCount + 25 * exactActionCount .aggressive profile := by
        simpa only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hBalance
      exact Nat.add_left_cancel hReordered
    have hAggressivePay := exactNash_moderate_deviation_bound params profile hNash
      aggressiveIndex AgentAction.aggressive hAggressiveAction
    simp only [exactActionPenalty, exactActionViolates, Bool.false_eq_true, if_false,
      exactActionQuality, Nat.mul_zero, Nat.add_zero] at hAggressivePay
    by_cases hUpdatedOverflow : params.totalBudget <
        exactTotalTokens (exactUpdate profile aggressiveIndex .moderate)
    · have hUpdatedRecovery := exactOverflow_add_budget_of_lt params
        (exactUpdate profile aggressiveIndex .moderate) hUpdatedOverflow
      have hOverflowDrop : exactOverflow params profile =
          exactOverflow params (exactUpdate profile aggressiveIndex .moderate) + 25 := by
        have hTotals :
            (exactOverflow params (exactUpdate profile aggressiveIndex .moderate) + 25) +
                params.totalBudget =
              exactOverflow params profile + params.totalBudget := by
          calc
            (exactOverflow params (exactUpdate profile aggressiveIndex .moderate) + 25) +
                params.totalBudget =
              (exactOverflow params (exactUpdate profile aggressiveIndex .moderate) +
                params.totalBudget) + 25 := by
                  simp only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
            _ = exactTotalTokens (exactUpdate profile aggressiveIndex .moderate) + 25 :=
              congrArg (fun value => value + 25) hUpdatedRecovery
            _ = exactTotalTokens profile := hAggressiveTotal
            _ = exactOverflow params profile + params.totalBudget := hOverflowRecovery.symm
        exact (Nat.add_right_cancel hTotals).symm
      rw [hOverflowDrop] at hAggressivePay
      have hCancel : 7 * params.agentCount + 25 ≤ 9 * params.agentCount := by
        have hReordered :
            (7 * params.agentCount + 25) +
                exactOverflow params (exactUpdate profile aggressiveIndex .moderate) ≤
              9 * params.agentCount +
                exactOverflow params (exactUpdate profile aggressiveIndex .moderate) := by
          simpa only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm,
            Nat.mul_comm, Nat.zero_add] using hAggressivePay
        exact Nat.le_of_add_le_add_right hReordered
      exact (Nat.not_lt_of_ge hCancel (exactAggressive_deviation_strict hSmall)).elim
    · have hUpdatedWithin : exactTotalTokens
          (exactUpdate profile aggressiveIndex .moderate) ≤ params.totalBudget :=
        Nat.le_of_not_gt hUpdatedOverflow
      have hUpdatedOverflowZero := exactOverflow_eq_zero_of_le params
        (exactUpdate profile aggressiveIndex .moderate) hUpdatedWithin
      rw [hUpdatedOverflowZero, Nat.add_zero] at hAggressivePay
      have hOverflowTwo : exactOverflow params profile ≤ 2 * params.agentCount := by
        simp only [Nat.zero_add] at hAggressivePay
        have hNine : params.agentCount * 9 =
            params.agentCount * 7 + params.agentCount * 2 := by
          calc
            params.agentCount * 9 = params.agentCount * (7 + 2) := rfl
            _ = params.agentCount * 7 + params.agentCount * 2 := Nat.mul_add _ _ _
        rw [hNine] at hAggressivePay
        simpa only [Nat.mul_comm] using Nat.le_of_add_le_add_left hAggressivePay
      have hOverflowTwentyFour : exactOverflow params profile ≤ 24 :=
        le_trans hOverflowTwo (by
          have h := Nat.mul_le_mul_left 2 hSmall
          change 2 * params.agentCount ≤ 24 at h
          exact h)
      have hConservativePositive : 0 < exactActionCount .conservative profile := by
        by_cases hPositive : 0 < exactActionCount .conservative profile
        · exact hPositive
        · have hConservativeEq : exactActionCount .conservative profile = 0 :=
            Nat.eq_zero_of_not_pos hPositive
          rw [hConservativeEq, Nat.mul_zero, Nat.add_zero] at hOverflowBalance
          have hTwentyFive : 25 ≤ 25 * exactActionCount .aggressive profile := by
            have hOne : 1 ≤ exactActionCount .aggressive profile := hAggressivePositive
            have h := Nat.mul_le_mul_left 25 hOne
            change 25 ≤ 25 * exactActionCount .aggressive profile at h
            exact h
          rw [← hOverflowBalance] at hTwentyFive
          have hImpossible : 25 ≤ 24 := le_trans hTwentyFive hOverflowTwentyFour
          exact False.elim ((by decide : ¬ (25 : Nat) ≤ 24) hImpossible)
      obtain ⟨conservativeIndex, hConservativeAction⟩ :=
        exactActionCount_lookup_of_pos .conservative profile hConservativePositive
      have hConservativeTotal := exactConservative_moderate_total params profile
        conservativeIndex hConservativeAction
      have hConservativeOverflowTotal : params.totalBudget <
          exactTotalTokens (exactUpdate profile conservativeIndex .moderate) := by
        rw [hConservativeTotal]
        exact lt_of_lt_of_le hOverflowTotal (Nat.le_add_right _ _)
      have hConservativeRecovery := exactOverflow_add_budget_of_lt params
        (exactUpdate profile conservativeIndex .moderate) hConservativeOverflowTotal
      have hConservativeOverflow :
          exactOverflow params (exactUpdate profile conservativeIndex .moderate) =
            exactOverflow params profile + 15 := by
        have hTotals :
            exactOverflow params (exactUpdate profile conservativeIndex .moderate) +
                params.totalBudget =
              (exactOverflow params profile + 15) + params.totalBudget := by
          rw [hConservativeRecovery, hConservativeTotal, ← hOverflowRecovery]
          simp only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
        exact Nat.add_right_cancel hTotals
      have hConservativePay := exactNash_moderate_deviation_bound params profile hNash
        conservativeIndex AgentAction.conservative hConservativeAction
      simp only [exactActionPenalty, exactActionViolates, Bool.false_eq_true, if_false,
        exactActionQuality, Nat.mul_zero, Nat.add_zero, hConservativeOverflow] at hConservativePay
      have hFour : 4 * params.agentCount ≤ 15 := by
        have hReordered :
            (params.agentCount * 3 + params.agentCount * 4) +
                exactOverflow params profile ≤
              (params.agentCount * 3 + 15) + exactOverflow params profile := by
          simpa only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm,
            ← Nat.mul_add, Nat.zero_add] using hConservativePay
        have hCancelOverflow := Nat.le_of_add_le_add_right hReordered
        have h := Nat.le_of_add_le_add_left hCancelOverflow
        rw [Nat.mul_comm params.agentCount 4] at h
        exact h
      have hThree : params.agentCount ≤ 3 := by
        by_cases hThree : params.agentCount ≤ 3
        · exact hThree
        · have hFourAgents : 4 ≤ params.agentCount := Nat.lt_of_not_ge hThree
          have hSixteen : 16 ≤ 4 * params.agentCount := by
            have h := Nat.mul_le_mul_left 4 hFourAgents
            change 16 ≤ 4 * params.agentCount at h
            exact h
          have hImpossible : 16 ≤ 15 := le_trans hSixteen hFour
          exact False.elim ((by decide : ¬ (16 : Nat) ≤ 15) hImpossible)
      have hCount : exactActionCount .aggressive profile +
          exactActionCount .conservative profile ≤ params.agentCount := by
        have hBase : exactActionCount .aggressive profile +
              exactActionCount .conservative profile ≤
            exactActionCount .conservative profile +
              exactActionCount .moderate profile + exactActionCount .aggressive profile := by
          have h := Nat.le_add_right
            (exactActionCount .aggressive profile + exactActionCount .conservative profile)
            (exactActionCount .moderate profile)
          simpa only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h
        rw [hPartition] at hBase
        exact hBase
      exact False.elim (exactOverflow_count_contradiction params.agentCount
        (exactActionCount .aggressive profile)
        (exactActionCount .conservative profile)
        (exactActionCount .moderate profile)
        (exactOverflow params profile) hAggressivePositive hConservativePositive
        hCount hThree hOverflowTwo hOverflowBalance)

/-- A small structural count system forced by a feasible conservative Nash action is inconsistent. -/
theorem exactConservative_count_contradiction
    (n aggressive conservative moderate overflow : Nat)
    (hPositive : 0 < n) (hAggressive : 0 < aggressive)
    (hConservative : 0 < conservative)
    (hCount : aggressive + conservative ≤ n)
    (hSmall : n ≤ 3) (hFour : 4 * n ≤ overflow)
    (hCost : 25 * aggressive ≤ 15 * conservative)
    (hBalance : overflow + 15 * conservative = 25 * aggressive + 15) : False := by
  have hConservativeTwo : conservative ≤ 2 := by
    have hOne : 1 ≤ aggressive := hAggressive
    have hStep : 1 + conservative ≤ aggressive + conservative :=
      Nat.add_le_add_right hOne conservative
    have hThree : 1 + conservative ≤ 3 :=
      le_trans hStep (le_trans hCount hSmall)
    have hThree' : conservative + 1 ≤ 2 + 1 := by
      rw [Nat.add_comm conservative 1]
      exact hThree
    exact Nat.le_of_add_le_add_right hThree'
  have hConservativeAtLeastTwo : 2 ≤ conservative := by
    by_cases hTwo : 2 ≤ conservative
    · exact hTwo
    · have hOne : conservative ≤ 1 := Nat.lt_succ_iff.mp (Nat.lt_of_not_ge hTwo)
      have hFifteen : 15 * conservative ≤ 15 := by
        have h := Nat.mul_le_mul_left 15 hOne
        change 15 * conservative ≤ 15 at h
        exact h
      have hTwentyFive : 25 ≤ 25 * aggressive := by
        have h := Nat.mul_le_mul_left 25 hAggressive
        change 25 ≤ 25 * aggressive at h
        exact h
      have hImpossible : 25 ≤ 15 := le_trans hTwentyFive (le_trans hCost hFifteen)
      exact False.elim ((by decide : ¬ (25 : Nat) ≤ 15) hImpossible)
  have hConservativeEq : conservative = 2 :=
    Nat.le_antisymm hConservativeTwo hConservativeAtLeastTwo
  have hAggressiveOne : aggressive ≤ 1 := by
    have hStep : aggressive + 2 ≤ 3 := by
      rw [← hConservativeEq]
      exact le_trans hCount hSmall
    change aggressive + 2 ≤ 1 + 2 at hStep
    exact Nat.le_of_add_le_add_right hStep
  have hAggressiveEq : aggressive = 1 := Nat.le_antisymm hAggressiveOne hAggressive
  have hThreeLower : 3 ≤ n := by
    rw [hAggressiveEq, hConservativeEq] at hCount
    exact hCount
  have hCountEq : n = 3 := Nat.le_antisymm hSmall hThreeLower
  rw [hAggressiveEq, hConservativeEq] at hBalance
  have hOverflowEq : overflow = 10 := by
    change overflow + 30 = 40 at hBalance
    change overflow + 30 = 10 + 30 at hBalance
    exact Nat.add_right_cancel hBalance
  rw [hCountEq, hOverflowEq] at hFour
  exact (by decide : ¬ (4 * 3 : Nat) ≤ 10) hFour

/-- Without overflow, no exact Nash profile contains a conservative action. -/
theorem exactNoConservative_inNash (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (profile : ExactProfile params.agentCount)
    (hNash : ExactIsNash params profile)
    (hNoNC : ∀ i, profile i ≠ AgentAction.noncompliant)
    (hWithin : exactTotalTokens profile ≤ params.totalBudget) :
    ∀ i, profile i ≠ AgentAction.conservative := by
  intro conservativeIndex hConservativeAction
  have hConservativePositive := exactActionCount_pos_of_lookup .conservative profile
    conservativeIndex hConservativeAction
  have hAggressivePositive : 0 < exactActionCount .aggressive profile := by
    by_cases hPositive : 0 < exactActionCount .aggressive profile
    · exact hPositive
    · have hAggressiveZero := Nat.eq_zero_of_not_pos hPositive
      have hBalance := exactTotalTokens_balance_no_noncompliant profile hNoNC
      rw [hAggressiveZero, Nat.mul_zero, Nat.add_zero] at hBalance
      have hConservativeCost : 15 ≤ 15 * exactActionCount .conservative profile := by
        have h := Nat.mul_le_mul_left 15 hConservativePositive
        change 15 ≤ 15 * exactActionCount .conservative profile at h
        exact h
      have hBudgetTotal : exactTotalTokens profile + 15 ≤ params.totalBudget := by
        calc
          exactTotalTokens profile + 15 ≤
              exactTotalTokens profile + 15 * exactActionCount .conservative profile :=
            Nat.add_le_add_left hConservativeCost _
          _ = 25 * params.agentCount := hBalance
          _ = params.totalBudget := hBudget.symm
      have hTotal := exactConservative_moderate_total params profile conservativeIndex
        hConservativeAction
      have hUpdatedWithin : exactTotalTokens
          (exactUpdate profile conservativeIndex .moderate) ≤ params.totalBudget := by
        rw [hTotal]
        exact hBudgetTotal
      have hOldOverflow := exactOverflow_eq_zero_of_le params profile hWithin
      have hNewOverflow := exactOverflow_eq_zero_of_le params
        (exactUpdate profile conservativeIndex .moderate) hUpdatedWithin
      have hPay := exactNash_moderate_deviation_bound params profile hNash
        conservativeIndex AgentAction.conservative hConservativeAction
      simp only [exactActionPenalty, exactActionViolates, Bool.false_eq_true, if_false,
        exactActionQuality, Nat.mul_zero, Nat.add_zero, hOldOverflow, hNewOverflow] at hPay
      have hStrict : params.agentCount * 3 < params.agentCount * 7 :=
        Nat.mul_lt_mul_of_pos_left (by decide) params.hPositive
      exact False.elim ((Nat.not_lt_of_ge hPay) hStrict)
  have hBalance := exactTotalTokens_balance_no_noncompliant profile hNoNC
  have hCost : 25 * exactActionCount .aggressive profile ≤
      15 * exactActionCount .conservative profile := by
    have hStep : exactTotalTokens profile +
          15 * exactActionCount .conservative profile ≤
        25 * params.agentCount + 15 * exactActionCount .conservative profile :=
      Nat.add_le_add_right (by simpa [hBudget] using hWithin) _
    rw [hBalance] at hStep
    exact Nat.le_of_add_le_add_left hStep
  have hOldOverflow := exactOverflow_eq_zero_of_le params profile hWithin
  have hConservativeTotal := exactConservative_moderate_total params profile
    conservativeIndex hConservativeAction
  have hPay := exactNash_moderate_deviation_bound params profile hNash
    conservativeIndex AgentAction.conservative hConservativeAction
  simp only [exactActionPenalty, exactActionViolates, Bool.false_eq_true, if_false,
    exactActionQuality, Nat.mul_zero, Nat.add_zero, hOldOverflow] at hPay
  have hFour : 4 * params.agentCount ≤
      exactOverflow params (exactUpdate profile conservativeIndex .moderate) := by
    have hSeven : params.agentCount * 7 =
        params.agentCount * 3 + params.agentCount * 4 := by rw [← Nat.mul_add]
    rw [hSeven] at hPay
    simpa [Nat.mul_comm] using Nat.le_of_add_le_add_left hPay
  have hUpdatedOverflowPositive : 0 <
      exactOverflow params (exactUpdate profile conservativeIndex .moderate) :=
    lt_of_lt_of_le (Nat.mul_pos (by decide) params.hPositive) hFour
  have hUpdatedOverflowTotal : params.totalBudget <
      exactTotalTokens (exactUpdate profile conservativeIndex .moderate) := by
    unfold exactOverflow at hUpdatedOverflowPositive
    exact (Nat.sub_pos_iff_lt).mp hUpdatedOverflowPositive
  have hUpdatedRecovery := exactOverflow_add_budget_of_lt params
    (exactUpdate profile conservativeIndex .moderate) hUpdatedOverflowTotal
  have hOverflowBalance :
      exactOverflow params (exactUpdate profile conservativeIndex .moderate) +
          15 * exactActionCount .conservative profile =
        25 * exactActionCount .aggressive profile + 15 := by
    rw [hConservativeTotal] at hUpdatedRecovery
    have hReordered : 25 * params.agentCount +
          (exactOverflow params (exactUpdate profile conservativeIndex .moderate) +
            15 * exactActionCount .conservative profile) =
        25 * params.agentCount +
          (25 * exactActionCount .aggressive profile + 15) := by
      rw [hBudget] at hUpdatedRecovery
      calc
        25 * params.agentCount +
            (exactOverflow params (exactUpdate profile conservativeIndex .moderate) +
              15 * exactActionCount .conservative profile) =
          (exactOverflow params (exactUpdate profile conservativeIndex .moderate) +
              25 * params.agentCount) +
            15 * exactActionCount .conservative profile := by
              simp only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
        _ = (exactTotalTokens profile + 15) +
            15 * exactActionCount .conservative profile :=
          congrArg (fun value => value + 15 * exactActionCount .conservative profile)
            hUpdatedRecovery
        _ = (exactTotalTokens profile +
            15 * exactActionCount .conservative profile) + 15 := by
              simp only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
        _ = (25 * params.agentCount +
            25 * exactActionCount .aggressive profile) + 15 :=
          congrArg (fun value => value + 15) hBalance
        _ = 25 * params.agentCount +
            (25 * exactActionCount .aggressive profile + 15) := Nat.add_assoc _ _ _
    exact Nat.add_left_cancel hReordered
  have hNCZero : exactActionCount .noncompliant profile = 0 :=
    exactActionCount_eq_zero_of_forall_ne .noncompliant profile hNoNC
  have hPartition := exactActionCount_partition profile
  rw [hNCZero, Nat.add_zero] at hPartition
  have hCount : exactActionCount .aggressive profile +
      exactActionCount .conservative profile ≤ params.agentCount := by
    have hBase : exactActionCount .aggressive profile +
          exactActionCount .conservative profile ≤
        exactActionCount .conservative profile +
          exactActionCount .moderate profile + exactActionCount .aggressive profile :=
      by
        have h := Nat.le_add_right
          (exactActionCount .aggressive profile + exactActionCount .conservative profile)
          (exactActionCount .moderate profile)
        simpa only [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h
    rw [hPartition] at hBase
    exact hBase
  have hFifteen : exactOverflow params
        (exactUpdate profile conservativeIndex .moderate) ≤ 15 := by
    have hUpper : 25 * exactActionCount .aggressive profile + 15 ≤
        15 * exactActionCount .conservative profile + 15 :=
      Nat.add_le_add_right hCost 15
    rw [← hOverflowBalance] at hUpper
    have hReordered : exactOverflow params
          (exactUpdate profile conservativeIndex .moderate) +
            15 * exactActionCount .conservative profile ≤
        15 + 15 * exactActionCount .conservative profile := by
      simpa only [Nat.add_comm] using hUpper
    exact Nat.le_of_add_le_add_right hReordered
  have hThree : params.agentCount ≤ 3 := by
    by_cases hThree : params.agentCount ≤ 3
    · exact hThree
    · have hFourAgents : 4 ≤ params.agentCount := Nat.lt_of_not_ge hThree
      have hSixteen : 16 ≤ 4 * params.agentCount := by
        have h := Nat.mul_le_mul_left 4 hFourAgents
        change 16 ≤ 4 * params.agentCount at h
        exact h
      have hImpossible : 16 ≤ 15 := le_trans hSixteen (le_trans hFour hFifteen)
      exact False.elim ((by decide : ¬ (16 : Nat) ≤ 15) hImpossible)
  exact exactConservative_count_contradiction params.agentCount
    (exactActionCount .aggressive profile)
    (exactActionCount .conservative profile)
    (exactActionCount .moderate profile)
    (exactOverflow params (exactUpdate profile conservativeIndex .moderate))
    params.hPositive hAggressivePositive hConservativePositive hCount hThree hFour
    hCost hOverflowBalance

/-- With no noncompliant or conservative action, feasibility excludes aggressive actions. -/
theorem exactNoAggressive_inFeasibleBalanced (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (profile : ExactProfile params.agentCount)
    (hNoNC : ∀ i, profile i ≠ AgentAction.noncompliant)
    (hNoConservative : ∀ i, profile i ≠ AgentAction.conservative)
    (hWithin : exactTotalTokens profile ≤ params.totalBudget) :
    ∀ i, profile i ≠ AgentAction.aggressive := by
  have hConservativeZero : exactActionCount .conservative profile = 0 :=
    exactActionCount_eq_zero_of_forall_ne .conservative profile hNoConservative
  have hBalance := exactTotalTokens_balance_no_noncompliant profile hNoNC
  rw [hConservativeZero, Nat.mul_zero, Nat.add_zero] at hBalance
  intro i hi
  have hAggressivePositive := exactActionCount_pos_of_lookup .aggressive profile i hi
  have hOne : 1 ≤ exactActionCount .aggressive profile := hAggressivePositive
  have hTwentyFive : 25 ≤ 25 * exactActionCount .aggressive profile := by
    have h := Nat.mul_le_mul_left 25 hOne
    change 25 ≤ 25 * exactActionCount .aggressive profile at h
    exact h
  have hExtra : 25 * params.agentCount + 25 ≤ exactTotalTokens profile := by
    rw [hBalance]
    exact Nat.add_le_add_left hTwentyFive _
  have hBudgetLe : exactTotalTokens profile ≤ 25 * params.agentCount := by
    rw [← hBudget]
    exact hWithin
  have : 25 * params.agentCount + 25 ≤ 25 * params.agentCount :=
    le_trans hExtra hBudgetLe
  have hStrict : 25 * params.agentCount < 25 * params.agentCount + 25 :=
    Nat.lt_add_of_pos_right (by decide)
  exact (Nat.not_lt_of_ge this hStrict).elim

/-- Every exact pure Nash profile is pointwise all-moderate for positive `n ≤ 12`. -/
theorem exactNash_eq_allModerate (params : BudgetParams)
    (hBudget : params.totalBudget = 25 * params.agentCount)
    (hSmall : params.agentCount ≤ 12)
    (profile : ExactProfile params.agentCount)
    (hNash : ExactIsNash params profile) :
    ∀ i, profile i = AgentAction.moderate := by
  have hNoNC := exactNoNoncompliant_inNash params profile hNash
  have hWithin := exactNoOverflow_inNash params hBudget hSmall profile hNash hNoNC
  have hNoConservative := exactNoConservative_inNash params hBudget profile hNash hNoNC hWithin
  have hNoAggressive := exactNoAggressive_inFeasibleBalanced params hBudget profile
    hNoNC hNoConservative hWithin
  intro i
  cases hAction : profile i with
  | conservative => exact (hNoConservative i hAction).elim
  | moderate => rfl
  | aggressive => exact (hNoAggressive i hAction).elim
  | noncompliant => exact (hNoNC i hAction).elim

end Fulcrum.GameTheory
