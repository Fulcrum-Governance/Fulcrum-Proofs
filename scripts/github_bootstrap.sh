#!/usr/bin/env bash
set -euo pipefail

OWNER="Fulcrum-Governance"
REPO="Fulcrum-Proofs"
BRANCH="main"

usage() {
  cat <<EOF
Usage: $0 [--owner <org-or-user>] [--repo <repo-name>] [--branch <default-branch>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)
      OWNER="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found" >&2
  exit 1
fi

echo "[1/3] Creating environments"
for env in ci bench-nightly investor-evidence; do
  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "repos/$OWNER/$REPO/environments/$env" >/dev/null
  echo " - ensured environment: $env"
done

echo "[2/3] Applying branch protection for $BRANCH"
PAYLOAD="$(mktemp)"
cat > "$PAYLOAD" <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["proof-gate", "model-gate", "evidence-gate"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "repos/$OWNER/$REPO/branches/$BRANCH/protection" \
  --input "$PAYLOAD" >/dev/null
rm -f "$PAYLOAD"

echo "[3/3] Branch protection applied: $OWNER/$REPO@$BRANCH"
