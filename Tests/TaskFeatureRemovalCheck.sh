#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"

if rg -n 'thread/list|onTasksChange|TaskStatus|TaskRowView|CodexSessionActivity|openTask|CodexNavigat' Sources; then
  print -u2 'FAIL: task monitoring or task presentation code remains in Sources'
  exit 1
fi

print 'PASS: task monitoring, task presentation, and task navigation are absent'
