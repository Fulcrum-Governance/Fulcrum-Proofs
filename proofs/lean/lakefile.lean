import Lake
open Lake DSL

package "fulcrum_proofs" where
  moreLeanArgs := #[]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4"

lean_lib "Proofs" where
  roots := #[`Proofs]
