/-
  Structural roster, sum, lookup, and update lemmas for the exact game.
-/

import Proofs.GameTheory.ExactDefinitions

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- `List.ofFn` contains exactly one roster entry for every profile index. -/
@[simp] theorem exactRoster_length {n : Nat} (profile : ExactProfile n) :
    (exactRoster profile).length = n := by
  simp [exactRoster]

/-- `List.ofFn` lookup recovers the profile value at every `Fin n` index. -/
@[simp] theorem exactRoster_get {n : Nat} (profile : ExactProfile n) (i : Fin n) :
    (exactRoster profile)[i.val]'(by simpa [exactRoster] using i.isLt) = profile i := by
  simp [exactRoster]

/-- A unilateral update takes the replacement action at the changed index. -/
@[simp] theorem exactUpdate_same {n : Nat} (profile : ExactProfile n)
    (i : Fin n) (a : AgentAction) : exactUpdate profile i a i = a := by
  exact Function.update_self i a profile

/-- A unilateral update preserves every unchanged index. -/
@[simp] theorem exactUpdate_of_ne {n : Nat} (profile : ExactProfile n)
    (i j : Fin n) (a : AgentAction) (h : j ≠ i) :
    exactUpdate profile i a j = profile j := by
  exact Function.update_of_ne h a profile

/-- Structural sum of a constant natural-valued profile. -/
theorem structuralSum_const (c n : Nat) :
    structuralSum (fun _ : Unit => c) (fun _ : Fin n => ()) = c * n := by
  induction n with
  | zero => rfl
  | succ n ih =>
      simp only [structuralSum]
      rw [ih, Nat.mul_succ]
      exact Nat.add_comm _ _

/-- Structural sums agree when their profiles agree pointwise. -/
theorem structuralSum_congr {α : Type} (f : α → Nat) {n : Nat}
    (profile₁ profile₂ : Fin n → α) (h : ∀ i, profile₁ i = profile₂ i) :
    structuralSum f profile₁ = structuralSum f profile₂ := by
  induction n with
  | zero => rfl
  | succ n ih =>
      change f (profile₁ 0) + structuralSum f (fun i : Fin n => profile₁ i.succ) =
        f (profile₂ 0) + structuralSum f (fun i : Fin n => profile₂ i.succ)
      rw [h 0]
      exact congrArg (Nat.add (f (profile₂ 0)))
        (ih (fun i : Fin n => profile₁ i.succ)
          (fun i : Fin n => profile₂ i.succ) (fun i => h i.succ))

/-- Updating a successor index commutes pointwise with taking the profile tail. -/
theorem structuralUpdate_tail {α : Type} {n : Nat} (profile : Fin (n + 1) → α)
    (i j : Fin n) (a : α) :
    Function.update profile i.succ a j.succ =
      Function.update (fun k : Fin n => profile k.succ) i a j := by
  by_cases h : j = i
  · subst j
    rw [Function.update_self, Function.update_self]
  · have hs : j.succ ≠ i.succ := fun e => h (Fin.succ_injective _ e)
    rw [Function.update_of_ne hs, Function.update_of_ne h]

/-- One-index structural-sum update identity, without subtraction. -/
theorem structuralSum_update_general {α : Type} (f : α → Nat) {n : Nat}
    (profile : Fin n → α) (i : Fin n) (a : α) :
    structuralSum f (Function.update profile i a) + f (profile i) =
      structuralSum f profile + f a := by
  induction n with
  | zero => exact Fin.elim0 i
  | succ n ih =>
      refine Fin.cases ?_ (fun j => ?_) i
      · have htail : ∀ k : Fin n,
            Function.update profile 0 a k.succ = profile k.succ := by
          intro k
          exact Function.update_of_ne (Fin.succ_ne_zero k) a profile
        change (f (Function.update profile 0 a 0) +
            structuralSum f (fun k : Fin n => Function.update profile 0 a k.succ)) +
              f (profile 0) =
          (f (profile 0) + structuralSum f (fun k : Fin n => profile k.succ)) + f a
        rw [Function.update_self]
        rw [structuralSum_congr f _ _ htail]
        calc
          (f a + structuralSum f (fun k : Fin n => profile k.succ)) + f (profile 0) =
              f a + (structuralSum f (fun k : Fin n => profile k.succ) +
                f (profile 0)) := Nat.add_assoc _ _ _
          _ = f a + (f (profile 0) +
                structuralSum f (fun k : Fin n => profile k.succ)) :=
              congrArg (Nat.add (f a)) (Nat.add_comm _ _)
          _ = (f (profile 0) + structuralSum f (fun k : Fin n => profile k.succ)) +
                f a := Nat.add_comm _ _
      · have hzero : Function.update profile j.succ a 0 = profile 0 :=
          Function.update_of_ne (Fin.succ_ne_zero j).symm a profile
        have htail : ∀ k : Fin n,
            Function.update profile j.succ a k.succ =
              Function.update (fun k : Fin n => profile k.succ) j a k :=
          fun k => structuralUpdate_tail profile j k a
        change (f (Function.update profile j.succ a 0) +
            structuralSum f (fun k : Fin n => Function.update profile j.succ a k.succ)) +
              f (profile j.succ) =
          (f (profile 0) + structuralSum f (fun k : Fin n => profile k.succ)) + f a
        rw [hzero]
        rw [structuralSum_congr f _ _ htail]
        calc
          (f (profile 0) +
              structuralSum f (Function.update (fun k => profile k.succ) j a)) +
                f (profile j.succ) =
              f (profile 0) +
                (structuralSum f (Function.update (fun k => profile k.succ) j a) +
                  f (profile j.succ)) := Nat.add_assoc _ _ _
          _ = f (profile 0) +
                (structuralSum f (fun k => profile k.succ) + f a) :=
              congrArg (Nat.add (f (profile 0)))
                (ih (fun k : Fin n => profile k.succ) j)
          _ = (f (profile 0) + structuralSum f (fun k => profile k.succ)) + f a :=
              (Nat.add_assoc _ _ _).symm

/-- One-agent exact token-total update identity, without subtraction. -/
theorem exactTotalTokens_update_general {n : Nat} (profile : ExactProfile n)
    (i : Fin n) (a : AgentAction) :
    exactTotalTokens (exactUpdate profile i a) + exactActionCost (profile i) =
      exactTotalTokens profile + exactActionCost a := by
  exact structuralSum_update_general exactActionCost profile i a

/-- All-moderate spends exactly 25 tokens per agent. -/
theorem exactAllModerate_totalTokens (n : Nat) :
    exactTotalTokens (exactAllModerate n) = 25 * n := by
  induction n with
  | zero => rfl
  | succ n ih =>
      change 25 + exactTotalTokens (exactAllModerate n) = 25 * (n + 1)
      rw [ih, Nat.mul_succ]
      exact Nat.add_comm _ _

/-- Every structural summand is bounded by the full structural sum. -/
theorem structuralSum_lookup_le {α : Type} (f : α → Nat) {n : Nat}
    (profile : Fin n → α) (i : Fin n) :
    f (profile i) ≤ structuralSum f profile := by
  induction n with
  | zero => exact Fin.elim0 i
  | succ n ih =>
      refine Fin.cases ?_ (fun j => ?_) i
      · exact Nat.le_add_right _ _
      · exact le_trans (ih (fun k : Fin n => profile k.succ) j) (Nat.le_add_left _ _)

/-- An index whose profile value is `a` contributes positively to its count. -/
theorem exactActionCount_pos_of_lookup {n : Nat} (a : AgentAction)
    (profile : ExactProfile n) (i : Fin n) (hi : profile i = a) :
    0 < exactActionCount a profile := by
  have h := structuralSum_lookup_le (fun b => if b = a then 1 else 0) profile i
  rw [hi, if_pos rfl] at h
  exact h

/-- A positive action count supplies an index playing that action. -/
theorem exactActionCount_lookup_of_pos {n : Nat} (a : AgentAction)
    (profile : ExactProfile n) (hpos : 0 < exactActionCount a profile) :
    ∃ i : Fin n, profile i = a := by
  induction n with
  | zero => simp [exactActionCount, structuralSum] at hpos
  | succ n ih =>
      by_cases h0 : profile 0 = a
      · exact ⟨0, h0⟩
      · have htail : 0 < exactActionCount a (fun i : Fin n => profile i.succ) := by
          simpa [exactActionCount, structuralSum, h0] using hpos
        obtain ⟨i, hi⟩ := ih (fun j : Fin n => profile j.succ) htail
        exact ⟨i.succ, hi⟩

/-- If an action is absent pointwise, its structural count is zero. -/
theorem exactActionCount_eq_zero_of_forall_ne {n : Nat} (a : AgentAction)
    (profile : ExactProfile n) (hAbsent : ∀ i, profile i ≠ a) :
    exactActionCount a profile = 0 := by
  induction n with
  | zero => rfl
  | succ n ih =>
      have h0 : profile 0 ≠ a := hAbsent 0
      have htail : ∀ i : Fin n, profile i.succ ≠ a := fun i => hAbsent i.succ
      simpa [exactActionCount, structuralSum, h0] using
        ih (fun i : Fin n => profile i.succ) htail

/-- The four structural action counts partition every profile. -/
theorem exactActionCount_partition {n : Nat} (profile : ExactProfile n) :
    exactActionCount .conservative profile +
      exactActionCount .moderate profile +
      exactActionCount .aggressive profile +
      exactActionCount .noncompliant profile = n := by
  induction n with
  | zero => rfl
  | succ n ih =>
      have h := ih (fun i : Fin n => profile i.succ)
      cases h0 : profile 0 <;>
        simp [exactActionCount, structuralSum, h0,
          Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] at h ⊢ <;>
        rw [h] <;> exact Nat.add_comm _ _

/-- Structural token total expressed by the four action counts. -/
theorem exactTotalTokens_count_formula {n : Nat} (profile : ExactProfile n) :
    exactTotalTokens profile =
      10 * exactActionCount .conservative profile +
      25 * exactActionCount .moderate profile +
      50 * exactActionCount .aggressive profile +
      40 * exactActionCount .noncompliant profile := by
  induction n with
  | zero => rfl
  | succ n ih =>
      have h := ih (fun i : Fin n => profile i.succ)
      cases h0 : profile 0 <;>
        simp [exactTotalTokens, exactActionCount, structuralSum,
          exactActionCost, h0, Nat.mul_add, Nat.add_assoc,
          Nat.add_comm, Nat.add_left_comm] at h ⊢ <;>
        exact h

/-- Structural total quality expressed by the four action counts. -/
theorem exactTotalQuality_count_formula {n : Nat} (profile : ExactProfile n) :
    exactTotalQuality profile =
      3 * exactActionCount .conservative profile +
      7 * exactActionCount .moderate profile +
      9 * exactActionCount .aggressive profile +
      8 * exactActionCount .noncompliant profile := by
  induction n with
  | zero => rfl
  | succ n ih =>
      have h := ih (fun i : Fin n => profile i.succ)
      cases h0 : profile 0 <;>
        simp [exactTotalQuality, exactActionCount, structuralSum,
          exactActionQuality, h0, Nat.mul_add, Nat.add_assoc,
          Nat.add_comm, Nat.add_left_comm] at h ⊢ <;>
        exact h

/-- Structural total penalty is twenty times the noncompliant count. -/
theorem exactTotalPenalty_count_formula {n : Nat} (profile : ExactProfile n) :
    exactTotalPenalty profile = 20 * exactActionCount .noncompliant profile := by
  induction n with
  | zero => rfl
  | succ n ih =>
      have h := ih (fun i : Fin n => profile i.succ)
      cases h0 : profile 0 <;>
        simp [exactTotalPenalty, exactActionCount, structuralSum,
          exactActionPenalty, exactActionViolates, exactViolationPenalty,
          h0, Nat.mul_add, Nat.add_assoc, Nat.add_comm,
          Nat.add_left_comm] at h ⊢ <;>
        exact h

/-- With no policy violator, token balance has a subtraction-free count form. -/
theorem exactTotalTokens_balance_no_noncompliant {n : Nat}
    (profile : ExactProfile n)
    (hNoNC : ∀ i, profile i ≠ AgentAction.noncompliant) :
    exactTotalTokens profile +
        15 * exactActionCount .conservative profile =
      25 * n + 25 * exactActionCount .aggressive profile := by
  induction n with
  | zero => rfl
  | succ n ih =>
      have htail : ∀ i : Fin n,
          profile i.succ ≠ AgentAction.noncompliant := fun i => hNoNC i.succ
      have h := ih (fun i : Fin n => profile i.succ) htail
      have hzero := hNoNC (0 : Fin (n + 1))
      cases hp : profile 0 with
      | conservative =>
          simp [exactTotalTokens, exactActionCount, structuralSum,
            exactActionCost, hp, Nat.mul_succ, Nat.mul_add,
            Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] at h ⊢
          rw [h]
          rw [← Nat.add_assoc]
      | moderate =>
          simp [exactTotalTokens, exactActionCount, structuralSum,
            exactActionCost, hp, Nat.mul_succ, Nat.mul_add,
            Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] at h ⊢
          rw [h]
      | aggressive =>
          simp [exactTotalTokens, exactActionCount, structuralSum,
            exactActionCost, hp, Nat.mul_succ, Nat.mul_add,
            Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] at h ⊢
          rw [h]
          rw [show (50 : Nat) = 25 + 25 by rfl, Nat.add_assoc]
      | noncompliant => exact (hzero hp).elim

/-- Overflow is zero whenever the total is within budget. -/
theorem exactOverflow_eq_zero_of_le (params : BudgetParams)
    (profile : ExactProfile params.agentCount)
    (h : exactTotalTokens profile ≤ params.totalBudget) :
    exactOverflow params profile = 0 := by
  simp [exactOverflow, Nat.sub_eq_zero_of_le h]

/-- Above budget, overflow plus the budget recovers the token total. -/
theorem exactOverflow_add_budget_of_lt (params : BudgetParams)
    (profile : ExactProfile params.agentCount)
    (h : params.totalBudget < exactTotalTokens profile) :
    exactOverflow params profile + params.totalBudget = exactTotalTokens profile := by
  simp [exactOverflow, Nat.sub_add_cancel (Nat.le_of_lt h)]

/-- Overflow is monotone in the token total. -/
theorem exactOverflow_mono (params : BudgetParams)
    (profile₁ profile₂ : ExactProfile params.agentCount)
    (h : exactTotalTokens profile₁ ≤ exactTotalTokens profile₂) :
    exactOverflow params profile₁ ≤ exactOverflow params profile₂ := by
  unfold exactOverflow
  exact Nat.sub_le_sub_right h params.totalBudget

end Fulcrum.GameTheory
