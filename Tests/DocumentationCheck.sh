#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h:h}"

# GitHub 的 macOS 镜像可能没有 ripgrep；以下检查仅用兼容 grep 的参数。
if (( ! $+commands[rg] )); then
    rg() { grep -E "$@"; }
fi

for readme in README.md README.zh-CN.md; do
    rg -qi 'forecast|预测' "$readme"
    rg -qi 'collecting|收集' "$readme"
    rg -qi 'current window|this window|本周期' "$readme"
    rg -qi 'unstable|不稳定' "$readme"
    rg -qi 'GitHub.*push|GitHub.*上传|GitHub.*推送|上传.*GitHub|推送.*GitHub' "$readme"
    rg -qi 'zero.?configuration|no configuration|无需配置|零配置' "$readme"
    rg -qi '30 minutes|30 分钟' "$readme"
    rg -qi '5 hours|5 小时' "$readme"
    rg -qi 'quota-history\.json' "$readme"
    rg -qi 'delete|deletion|删除' "$readme"
    rg -qi 'Universal 2' "$readme"
    rg -qi 'unzip|解压' "$readme"
    rg -qi 'Gatekeeper|安全性' "$readme"
    rg -qi 'drag-end|拖动结束' "$readme"
    rg -qi '28.?point|28.?点' "$readme"
    rg -qi '8.?point|8.?点' "$readme"
    rg -qi '350.?ms|350 毫秒' "$readme"
    rg -qi '250.?ms|250 毫秒' "$readme"
    rg -qi 'confidence|可信度' "$readme"
    rg -qi 'spike|用量突然升高' "$readme"
    rg -qi '15 minutes|15 分钟' "$readme"
    rg -qi 'graphite|石墨' "$readme"
    rg -qi 'reset.?card|重置卡' "$readme"
    rg -qi 'hover.*trend|悬停.*趋势' "$readme"
    rg -qi 'high.?contrast|高对比' "$readme"
    rg -qi 'weekly.*never|一周额度不会' "$readme"
    rg -qi 'task/session|任务或会话' "$readme"
done

print 'PASS: bilingual documentation covers install, presets, snapping, hover, forecast confidence, privacy, and local-only builds'
