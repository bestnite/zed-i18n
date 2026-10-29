#!/usr/bin/env bash
# Sync this fork with upstream LI-NA/zed-i18n and report what changed.
#
# Usage: scripts/sync-upstream.sh [--push]
#   --push   push the updated master to origin (no tags are pushed)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PUSH=0
for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/LI-NA/zed-i18n.git
  echo "added remote 'upstream' -> https://github.com/LI-NA/zed-i18n.git"
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "working tree is dirty; commit or stash first" >&2
  exit 1
fi

git fetch upstream --tags --quiet

BEFORE="$(cat config/project.toml 2>/dev/null || true)"

if git merge-base --is-ancestor upstream/master HEAD; then
  echo "already contains upstream/master; nothing to merge"
else
  git merge --no-edit upstream/master
fi

echo
echo "--- config/project.toml"
cat config/project.toml

AFTER="$(cat config/project.toml)"

if [ "$BEFORE" != "$AFTER" ]; then
  echo
  echo "Zed pin changed:"
  diff <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER") || true
fi

echo
echo "--- local commits on top of upstream"
git log --oneline upstream/master..HEAD

echo
echo "--- latest upstream release"
gh api repos/LI-NA/zed-i18n/releases/latest --jq '.tag_name' 2>/dev/null || echo "(gh unavailable)"

if [ "$PUSH" -eq 1 ]; then
  git push origin master
  echo "pushed origin/master"
else
  echo
  echo "next: review the diff, then 'git push origin master' (or rerun with --push),"
  echo "      then dispatch: gh workflow run windows-only.yml --repo bestnite/zed-i18n --ref master"
fi
