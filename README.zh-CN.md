# Codex Quota Rings · 额度双环

[English](README.md) · **简体中文**

一个轻量的 macOS 原生组件，用双环显示 Codex 的 **5 小时**与**一周**剩余额度，并提供额度趋势和当前任务状态。

![大卡片、展开详情和两种小组件布局，均为示例数据](assets/layouts.png)

## 安装与使用

安装包是**零配置、无需配置路径**的。拿到 `Quota-Rings.app.zip` 后解压，把 **Quota Rings.app** 拖入“应用程序”并双击打开。它会自动查找系统登记的 Codex、标准应用目录、Homebrew 位置及可执行路径，不需要终端命令。

正常打开 Codex 并登录即可。未安装 Codex 时，展开组件会显示“安装 Codex”；需要登录时会显示“打开 Codex”。安装、移动或重新登录后，组件会自动重新发现并重连。

安装包为 **Universal 2**，同时支持 Apple Silicon 与 Intel Mac；当本机存在兼容 Codex 时，应用最低目标为 macOS 12。当前社区包使用本地临时签名，没有公证。如果 Gatekeeper 阻止打开，请确认安装包来源后，在“系统设置 → 隐私与安全性”中选择“仍要打开”。

## 功能

- 大卡片、小型竖向双环、小型横向双环三种布局。
- 默认聚焦 Codex 时显示，也可以一直显示或只在清晰桌面上显示。
- 原生 AppKit 界面，每 30 秒自动读取额度，显示重置倒计时，无手动刷新按钮。
- 5 小时额度在同一周期收集至少 4 个且跨度达到 2 分钟的样本后预测用尽时间；收集中会明确提示，预测晚于重置时显示“本周期内不会用尽”。
- 5 小时消耗趋势图会识别重置，不会跨重置点画出误导曲线。
- 展示所有正在运行的本机 Codex 真实任务标题。`Running` 使用金棕色 `#B48A4A`；`Completed` 使用鼠尾草绿 `#8FA990`，完成后保留 5 分钟。
- 任务耗时从 Quota Rings 首次观察到本轮运行开始计算，完成时冻结，重启 Quota Rings 后重新计算。点击任务会尝试跳回 Codex 对应线程；深链不受支持或打开失败时，会把 Codex 切到前台。
- 剩余额度高于 50% 为鼠尾草绿，20–50% 为金棕色，低于 20% 为陶土红。

## 操作

右键组件或点击菜单栏圆环，可选择尺寸、小组件方向、显示范围、已用/剩余额度和趋势保留方式。拖动组件可调整位置，各种布局分别记住自己的位置。

| 分组 | 选项 |
| --- | --- |
| 大小 | 大 / 小 |
| 小组件布局 | 竖向 / 横向 |
| 显示范围 | 聚焦 Codex 时显示 / 一直显示 / 聚焦桌面时显示 |
| 趋势记录 | 仅本次 · 30 分钟 / 保留 24 小时 / 保留 7 天 |

## 隐私

默认只在内存中保留最近 **30 分钟**的趋势，不写趋势文件。只有用户主动选择 **保留 24 小时**或**保留 7 天**时，才会把时间戳和两个窗口的已用百分比保存在：

`~/Library/Application Support/Quota Rings/quota-history.json`

切回“仅本次 · 30 分钟”会立即删除该文件。额度历史不会写入任务 ID、任务标题、任务耗时、账户信息、凭证或原始协议内容。任务数据始终只在内存中，重启即清除。

Quota Rings 只通过 stdio 与本机 Codex app-server 子进程通信，自身不发起额外网络请求。Codex 可以使用已有登录状态和网络连接读取账户额度。

## 从源码构建

开发者需要 Xcode Command Line Tools；协议测试还需要 Python 3。

```sh
git clone https://github.com/innoerL/codex_quota_rings.git
cd codex_quota_rings
make test
make build
```

构建会分别编译 arm64 与 x86_64，合并为 Universal 2，验证本地签名与 ZIP 完整性，然后生成：

- `build/Quota Rings.app`
- `outputs/QuotaRings/Quota Rings.app`
- `outputs/QuotaRings/Quota-Rings.app.zip`

`make live-check` 可选，用于只读检查本机账户。原生窗口测试需要已登录的 macOS 图形会话。构建全程留在本机：不会上传或推送 GitHub，不会创建 GitHub Release，也不会把源码发送到其他位置。

## 故障排查

- **看不到组件**：点击菜单栏圆环，把显示范围改为“一直显示”。
- **未找到 Codex**：在展开详情中点击“安装 Codex”；组件会持续自动发现。
- **没有额度或双环变灰**：打开 Codex 并完成登录，组件会自动重试。
- **点击任务只把 Codex 切到前台**：当前 Codex 版本没有处理该线程深链，切到前台就是预期回退行为。
- **趋势消失**：仅本次模式会在退出时清空，选择 30 分钟模式也会删除此前持久化文件。

## 参与改进与许可

欢迎在 [innoerL/codex_quota_rings](https://github.com/innoerL/codex_quota_rings) 提交 Issue 或 Pull Request。公开截图请使用合成额度。本项目采用 [MIT License](LICENSE)，与 OpenAI 无隶属关系，也未获 OpenAI 背书。
