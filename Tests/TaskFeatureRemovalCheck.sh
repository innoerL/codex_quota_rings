#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"

if (( $+commands[rg] )); then
  search_output=$(rg -n 'thread/list|onTasksChange|TaskStatus|TaskRowView|CodexSessionActivity|openTask|CodexNavigat' Sources || true)
else
  search_output=$(grep -E -n -r 'thread/list|onTasksChange|TaskStatus|TaskRowView|CodexSessionActivity|openTask|CodexNavigat' Sources || true)
fi

if [[ -n "$search_output" ]]; then
  print -r -- "$search_output"
  print -u2 'FAIL: task monitoring or task presentation code remains in Sources'
  exit 1
fi

print 'PASS: task monitoring, task presentation, and task navigation are absent'
