# Contract Sync

`sync_contracts.sh` imports contracts from the Fulcrum repository into this repo.

It copies:
- proto contracts (`proto/fulcrum/**`)
- selected interface snapshots listed in `sources.yaml`

It writes `contracts/snapshots/version_manifest.yaml` with source commit metadata.
