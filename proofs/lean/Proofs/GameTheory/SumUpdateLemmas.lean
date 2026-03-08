import Proofs.GameTheory.FulcrumGame
import Mathlib.Data.Fintype.BigOperators

set_option autoImplicit false

namespace Fulcrum.GameTheory

/-- When summing a function over a profile updated at a single index, the result
    splits into the updated value plus the unchanged sum over the remaining indices. -/
lemma sum_comp_update {α : Type} {n : Nat} (i : Fin n) (a : α) (f : α → Nat)
    (g : Fin n → α) :
    (∑ j : Fin n, f (Function.update g i a j)) =
      f a + ∑ j ∈ Finset.univ.erase i, f (g j) := by
  rw [← Finset.add_sum_erase (s := Finset.univ)
    (f := fun j : Fin n => f (Function.update g i a j)) (a := i) (h := Finset.mem_univ i)]
  simp [Function.update_self]
  have hsum :
      (∑ j ∈ Finset.univ.erase i, f (Function.update g i a j)) =
        ∑ j ∈ Finset.univ.erase i, f (g j) := by
    refine Finset.sum_congr rfl ?_
    intro j hj
    rw [Function.update_of_ne]
    exact (Finset.mem_erase.mp hj).1
  exact hsum

/-- `totalTokens` after updating one agent in an all-moderate profile. -/
lemma totalTokens_update_allModerate (n : Nat) (i : Fin n) (a : AgentAction) :
    totalTokens n (Function.update (fun _ => AgentAction.moderate) i a) =
      actionTokenCost a + 25 * (n - 1) := by
  unfold totalTokens
  rw [sum_comp_update i a actionTokenCost (fun _ => AgentAction.moderate)]
  rw [Finset.sum_const_nat (s := Finset.univ.erase i) (m := 25)
    (f := fun j : Fin n => actionTokenCost ((fun _ => AgentAction.moderate) j))]
  · rw [Finset.card_erase_of_mem (Finset.mem_univ i), Finset.card_univ, Fintype.card_fin]
    simp [actionTokenCost, Nat.mul_comm]
  · intro j hj
    simp [actionTokenCost]

/-- `totalTokens` decomposes into the updated agent's cost plus the unchanged
    sum over all other agents. -/
lemma totalTokens_update_eq (n : Nat) (profile : Fin n → AgentAction)
    (i : Fin n) (a : AgentAction) :
    totalTokens n (Function.update profile i a) =
      actionTokenCost a + ∑ j ∈ Finset.univ.erase i, actionTokenCost (profile j) := by
  unfold totalTokens
  simpa using sum_comp_update i a actionTokenCost profile

/-- `totalTokens` decomposes into the current agent's cost plus the unchanged
    sum over all other agents. -/
lemma totalTokens_eq_cost_add_sum_erase (n : Nat) (profile : Fin n → AgentAction)
    (i : Fin n) :
    totalTokens n profile =
      actionTokenCost (profile i) + ∑ j ∈ Finset.univ.erase i, actionTokenCost (profile j) := by
  unfold totalTokens
  simpa using (Finset.add_sum_erase (s := Finset.univ)
    (f := fun j : Fin n => actionTokenCost (profile j)) (a := i) (h := Finset.mem_univ i)).symm

/-- One-agent `totalTokens` update identity, rearranged without subtraction. -/
lemma totalTokens_update_general (n : Nat) (profile : Fin n → AgentAction)
    (i : Fin n) (a : AgentAction) :
    totalTokens n (Function.update profile i a) + actionTokenCost (profile i) =
      totalTokens n profile + actionTokenCost a := by
  rw [totalTokens_update_eq (n := n) (profile := profile) (i := i) (a := a)]
  rw [totalTokens_eq_cost_add_sum_erase (n := n) (profile := profile) (i := i)]
  ac_rfl

/-- Sum of a constant real-valued function over `Fin n`. -/
lemma sum_const_real (n : Nat) (c : ℝ) :
    (∑ _ : Fin n, c) = c * n := by
  simp [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul, mul_comm]

end Fulcrum.GameTheory
