#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"

for readme in README.md README.zh-CN.md; do
    rg -qi 'forecast|预测' "$readme"
    rg -qi 'collecting|收集' "$readme"
    rg -qi 'current window|this window|本周期' "$readme"
    rg -qi 'unstable|不稳定' "$readme"
    rg -qi 'GitHub.*push|GitHub.*上传|GitHub.*推送|上传.*GitHub|推送.*GitHub' "$readme"
    rg -qi 'zero.?configuration|no configuration|无需配置|零配置' "$readme"
    rg -qi '30 minutes|30 分钟' "$readme"
    rg -qi '24 hours|24 小时' "$readme"
    rg -qi '7 days|7 天' "$readme"
    rg -qi 'quota-history\.json' "$readme"
    rg -qi 'delete|deletion|删除' "$readme"
    rg -qi 'Universal 2' "$readme"
    rg -qi 'unzip|解压' "$readme"
    rg -qi 'Gatekeeper|安全性' "$readme"
done

print 'PASS: bilingual documentation covers zero-config install, privacy, stable forecasts, Universal 2, and local-only builds'
