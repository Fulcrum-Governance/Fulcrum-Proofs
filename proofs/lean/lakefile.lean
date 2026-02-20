import Lake
open Lake DSL

package "fulcrum_proofs" where
  moreLeanArgs := #[]

lean_lib "Proofs" where
  roots := #[`Proofs]
