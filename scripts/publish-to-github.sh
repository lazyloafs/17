#!/usr/bin/env bash
# Publish this standalone optimizer tree to https://github.com/lazyloafs/localoptimizer
# Creates the repo if missing (requires a token with repo scope), then force-mirrors master.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REMOTE_URL="${LOCALOPTIMIZER_REMOTE:-https://github.com/lazyloafs/localoptimizer.git}"
BRANCH="${1:-master}"

echo "Publishing localoptimizer -> $REMOTE_URL ($BRANCH)"

# Prefer existing origin token if present
AUTH_URL="$REMOTE_URL"
if git remote get-url origin >/dev/null 2>&1; then
  ORIGIN="$(git remote get-url origin)"
  if [[ "$ORIGIN" == *"x-access-token:"* ]]; then
    TOKEN="$(echo "$ORIGIN" | sed -n 's|.*x-access-token:\([^@]*\)@.*|\1|p')"
    AUTH_URL="https://x-access-token:${TOKEN}@github.com/lazyloafs/localoptimizer.git"
  fi
fi

# Create repo if 404
CODE="$(curl -s -o /tmp/lo_repo.json -w '%{http_code}' -H "Authorization: token ${TOKEN:-}" \
  https://api.github.com/repos/lazyloafs/localoptimizer || true)"
if [[ "$CODE" == "404" ]]; then
  echo "Repo missing — attempting create under lazyloafs..."
  curl -s -X POST -H "Authorization: token ${TOKEN:-}" -H "Accept: application/vnd.github+json" \
    https://api.github.com/user/repos \
    -d '{"name":"localoptimizer","description":"Standalone Path of Building dual-phase deep optimizer (60+60 GA)","private":false,"auto_init":false}' \
    | tee /tmp/lo_create.json || true
fi

if git remote get-url localoptimizer >/dev/null 2>&1; then
  git remote set-url localoptimizer "$AUTH_URL"
else
  git remote add localoptimizer "$AUTH_URL"
fi

git push -u localoptimizer "HEAD:refs/heads/${BRANCH}" --force
echo "Published. Clone: git clone https://github.com/lazyloafs/localoptimizer"
