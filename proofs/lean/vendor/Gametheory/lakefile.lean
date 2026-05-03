import Lake
open Lake DSL

package «Gametheory» {
  -- add package configuration options here
}

@[default_target]
lean_lib «Gametheory» {
  -- add library configuration options here
}

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "06e947358d88e36af006f915f79a04a10fd43cc4"
