namespace Fulcrum

structure AgentBudget where
  currentSpent : Nat
  aggregateLimit : Nat

structure FinancialAction where
  delta : Nat

def applyAction (b : AgentBudget) (a : FinancialAction) : Option AgentBudget :=
  let spent' := b.currentSpent + a.delta
  if h : spent' <= b.aggregateLimit then
    some { currentSpent := spent', aggregateLimit := b.aggregateLimit }
  else
    none

theorem budget_safety_guarantee
  (b : AgentBudget) (a : FinancialAction) (newB : AgentBudget)
  (hExec : applyAction b a = some newB) :
  newB.currentSpent <= newB.aggregateLimit := by
  unfold applyAction at hExec
  by_cases h : b.currentSpent + a.delta <= b.aggregateLimit
  case pos =>
    simp [h] at hExec
    rcases hExec with rfl
    simpa using h
  case neg =>
    simp [h] at hExec

abbrev Cap := String
abbrev Caps := Set Cap

theorem subset_iff_diff_empty (cReq cA : Caps) :
  Set.Subset cReq cA <-> cReq \ cA = (Set.empty : Caps) := by
  constructor
  · intro h
    ext x
    constructor
    · intro hx
      exact (hx.2 (h hx.1)).elim
    · intro hx
      exact False.elim (by simpa using hx)
  · intro h
    intro x
    intro hxReq
    by_contra hxNotInA
    have hxDiff : x in cReq \ cA := And.intro hxReq hxNotInA
    have : x in (Set.empty : Caps) := by simpa [h] using hxDiff
    simpa using this

theorem thm_budget_local
  (b : AgentBudget) (a : FinancialAction) (newB : AgentBudget)
  (hExec : applyAction b a = some newB) :
  newB.currentSpent <= newB.aggregateLimit := by
  exact budget_safety_guarantee b a newB hExec

theorem thm_privilege_static (cReq cA : Caps) :
  Set.Subset cReq cA <-> cReq \ cA = (Set.empty : Caps) := by
  exact subset_iff_diff_empty cReq cA

end Fulcrum
