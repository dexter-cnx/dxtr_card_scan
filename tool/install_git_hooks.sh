#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hook_path="$repo_root/.git/hooks/pre-push"

cat >"$hook_path" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
exec bash "$repo_root/tool/pre_push.sh"
HOOK

chmod +x "$hook_path"
echo "Installed pre-push hook: $hook_path"
