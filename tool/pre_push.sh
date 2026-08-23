#!/usr/bin/env bash
set -euo pipefail

before_diff="$(mktemp)"
after_diff="$(mktemp)"
trap 'rm -f "$before_diff" "$after_diff"' EXIT

git diff --binary >"$before_diff"

make format
make rust-format

git diff --binary >"$after_diff"
if ! cmp -s "$before_diff" "$after_diff"; then
  echo >&2
  echo "Formatting changed tracked files. Review and commit those changes before pushing." >&2
  exit 1
fi

make format-check
make analyze
make test
make example-analyze
make rust-format-check
make rust-clippy
make rust-test
