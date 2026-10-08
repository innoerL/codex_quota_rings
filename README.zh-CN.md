# Codex Quota Rings · 额度双环

[English](README.md) · **简体中文**

一个轻量的 macOS 原生额度组件：随时查看 Codex 的 **5 小时**与**一周**剩余额度。

把额度变成桌面上一眼就能看懂的双环。它使用原生 AppKit 绘制，支持可展开大卡片和小巧双环，也能跟随 Codex 的前台状态自动出现，让你在工作时了解剩余额度和重置时间。

![大卡片、展开详情和两种小组件布局，均为示例数据](assets/layouts.png)

## 功能

- **大组件**：横向双环卡片，点击原位展开重置倒计时、重置日期和最近更新时间。
- **小组件**：横向或竖向双环，点击弹出详情；再次点击或点击外部关闭。
- **显示范围**：默认聚焦 Codex 时显示；也可选择一直显示、聚焦桌面时显示。
- **自动更新**：每 30 秒读取，并接收本地 app-server 的额度更新通知。
- **剩余额度颜色**：大于 50% 鼠尾草绿（`#8FA990`），20–50% 金棕色（`#B48A4A`），低于 20% 陶土红（`#BD7A70`）。过期或断连显示灰色并标注状态。
- 右键组件或点击菜单栏圆环图标更改设置；拖动组件改变位置。尺寸、方向、显示范围和各布局位置分别保存。

## 环境要求

- macOS 12 或更新版本，Apple Silicon 或 Intel Mac。
- Xcode Command Line Tools：运行 `xcode-select --install` 安装。
- 已安装并登录的 Codex CLI，支持 `codex app-server --listen stdio://` 及额度读取接口。
- 运行测试需要 Python 3。测试使用本地协议模拟器，不需要账户或网络。

## 构建与运行

```sh
git clone https://github.com/innoerL/codex_quota_rings.git
cd codex_quota_rings
make build
open 'build/Quota Rings.app'
```

`make build` 先执行测试，再为当前机器架构构建并本地签名。也可以使用 `make run`。

默认查找 `/usr/local/bin/codex`、`/opt/homebrew/bin/codex` 和 `/Applications/Codex.app/Contents/Resources/codex`。如果 CLI 位于其他位置，直接启动应用可传入路径：

```sh
QUOTA_CODEX_PATH="$(command -v codex)" 'build/Quota Rings.app/Contents/MacOS/QuotaRings'
```

组件是辅助应用，不显示 Dock 图标。通过菜单栏圆环菜单退出。源码构建使用本地临时签名，尚未提供公证安装包或自动更新。

## 显示范围

| 选项 | 行为 |
| --- | --- |
| 聚焦 Codex 时显示（默认） | Codex 应用在前台且存在可见窗口时显示 |
| 一直显示 | 浮在其他应用上方，点击组件不会激活它 |
| 聚焦桌面时显示 | Finder 在前台且屏幕上没有普通应用窗口时显示 |

桌面模式使用 macOS 前台应用和窗口信息判断。Finder 文件夹窗口不等于桌面；多显示器上仍有应用窗口，或桌面状态无法确定时，会保守隐藏。它模拟桌面组件的使用方式，并非 WidgetKit 扩展，不支持系统“编辑小组件”面板。

## 开发与验证

```sh
make test        # 模型、协议、偏好、菜单、显隐、绘制、窗口交互、公开文件检查
make live-check  # 可选：查询本机已登录账户，验证两次读取
make clean       # 仅清理 build/ 下的生成文件
```

测试图片写入 `build/`，使用合成数据。`make live-check` 不在 CI 中执行，真实额度不进入公开截图。请参阅 [贡献指南](CONTRIBUTING.md)。

## 隐私

组件通过本机 Codex CLI 的 stdio app-server 通道初始化连接、读取额度并接收相关通知。不启动模型任务，不修改账户或额度，不读取登录凭证文件，不保存额度历史，也不记录原始响应。显示偏好及窗口位置保存在 macOS UserDefaults 中。

组件自身不连接远程服务器。Codex CLI 可能使用它既有的登录和网络连接获取额度；CLI 的行为由其安装版本和配置决定。

## 故障排查与限制

- **看不到组件**：默认仅在 Codex 前台显示；从菜单栏将显示范围改为“一直显示”检查。
- **找不到 CLI**：确认 CLI 路径，并用上述 `QUOTA_CODEX_PATH` 启动命令指定。
- **暂无数据、灰环或断连**：确认 Codex 已登录且账户提供这两个额度窗口；组件会自动重试。超过 90 秒未更新会标记过期。
- app-server 接口和 Codex 应用标识可能随版本变化。此项目依赖本机提供的兼容接口，不保证所有 Codex 版本或账户类型都支持。
- 原生界面目前为简体中文；欢迎贡献其他语言。

## 参与改进

欢迎通过 [Issues](https://github.com/innoerL/codex_quota_rings/issues) 报告问题或提出建议，也欢迎提交 Pull Request。界面细节、桌面模式兼容性、无障碍和多语言支持都可以一起完善。提交截图时请使用示例数据，更多说明见 [贡献指南](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)。这是独立的社区项目，与 OpenAI 无隶属关系，也未获 OpenAI 背书。
