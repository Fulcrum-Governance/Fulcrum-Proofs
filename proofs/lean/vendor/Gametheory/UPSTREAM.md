# Vendored upstream — Gametheory (math-xmum/Brouwer fork)

## Source

- **Upstream URL**: https://github.com/math-xmum/Brouwer.git
- **Vendored from branch**: `fulcrum-v4.29-port`
- **Vendored from SHA**: `1355a1c49ee5689f5102fe7b3b9419947a7d181f` (1 commit ahead of upstream `main`)
- **Commit message**: `chore: port to Lean 4.29.0-rc4 for Fulcrum-Proofs use`
- **Vendored on**: 2026-05-03

## License

MIT — Copyright (c) 2025 Math_XMUM. License preserved at `./LICENSE` per MIT terms.

## Why vendored

This package was previously required via a sibling-path require:
```lean
require «Gametheory» from ".." / ".." / ".." / "math-xmum-brouwer-fork"
```

That broke CI because runners have no sibling repo. Vendoring eliminates the entire class of "sibling repo missing in CI" failures with a 224 KB one-time cost. The load-bearing port commit (`1355a1c`) exists only on the local working tree — it was never pushed upstream — so vendoring is also the simplest provenance-preserving path.

## Sync procedure (if upstream advances)

The upstream `main` has moved past the SHA we ported from. To re-sync:

1. Check out upstream main at the new target SHA
2. Re-port the Lean 4.29.0-rc4 changes (port commit `1355a1c` is local-only; not on upstream)
3. Update `lake-manifest.json` mathlib pin to match the new upstream's pin
4. Replace files in this directory
5. Update `Vendored from SHA` above

This is a manual process; there is no automated sync.

## Local backup

Pre-vendor working tree backed up at:
`~/fulcrum-local-backups/math-xmum-brouwer-fork-1355a1c-2026-05-03/`

Includes the full fork tree + `.lake/` build cache (11 GB total — most of which is ephemeral build artifacts).

## Closes

- `Fulcrum-Governance/Fulcrum-Proofs#16` — F-020 follow-up (vendor or git-pin math-xmum-brouwer-fork to unblock proof-gate)

After this lands, the `proof-gate` CI workflow will pass naturally without admin-bypass — first time since the F-020 admin-bypass precedent began on 2026-05-01.
