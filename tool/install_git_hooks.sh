#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git config core.hooksPath .githooks
chmod +x .githooks/pre-push tool/pre_push.sh

echo "Configured core.hooksPath=.githooks"
echo "Pre-push hook: $repo_root/.githooks/pre-push"
