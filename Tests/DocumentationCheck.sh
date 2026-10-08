#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"

for readme in README.md README.zh-CN.md; do
    rg -qi 'forecast|预测' "$readme"
    rg -qi 'collecting|收集' "$readme"
    rg -qi 'current window|this window|本周期' "$readme"
    rg -qi 'real.*task|真实.*任务' "$readme"
    rg -qi 'five minutes|5 分钟' "$readme"
    rg -qi '#B48A4A' "$readme"
    rg -qi '#8FA990' "$readme"
    rg -qi 'GitHub.*push|GitHub.*上传|GitHub.*推送|上传.*GitHub|推送.*GitHub' "$readme"
done

print 'PASS: bilingual documentation covers forecasts, task status, palette, and local-only builds'
