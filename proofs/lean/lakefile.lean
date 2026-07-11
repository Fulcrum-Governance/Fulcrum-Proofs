import Lake
open Lake DSL

package "fulcrum_proofs" where
  moreLeanArgs := #[]

require «Gametheory» from "vendor" / "Gametheory"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "06e947358d88e36af006f915f79a04a10fd43cc4"

@[default_target]
lean_lib "Proofs" where
  roots := #[`Proofs]
