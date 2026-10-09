# 组件展示与预测可信度实施计划

> **面向执行代理：** 必须逐项执行并在每一步使用测试驱动开发；所有步骤均使用复选框跟踪。

**目标：** 为 Quota Rings 增加拖动结束时的 Codex 吸附与窗口避让、视觉预设、临时悬停详情，以及可信的 5 小时预测可信度。

**架构：** 将位置解析、悬停状态、展示度量和预测可信度拆分为可独立测试的模型。`QuotaApp` 提供实时 AppKit 窗口几何信息并应用解析结果；视图只消费度量和派生预测状态，不读取其他应用或 Codex 任务数据。

**技术栈：** Swift 5、AppKit、CoreGraphics、Foundation、UserDefaults、既有 Swift 可执行测试。

**对应设计说明：** `docs/superpowers/specs/2026-10-09-widget-presentation-confidence-design.zh-CN.md`

## 全局约束

- 支持 macOS 12，保持原生 AppKit 架构。
- 仅在用户拖动结束时吸附，绝不持续跟随 Codex 窗口。
- 吸附间距固定为 8 点，拖动结束的吸附阈值固定为 28 点。
- 透明度固定为 0.97、0.82、0.68；紧凑度缩放固定为 1.00、0.88、0.76。
- 悬停打开延迟为 350 毫秒；临时详情收起延迟为 250 毫秒。
- 不增加无障碍功能、任务/会话读取、任务跳转、通知、额外 Codex 方法或一周用尽预测。
- 英文与简体中文文档必须同步。

## 审查重点

- 拖动终点同时接近两个 Codex 边缘时，必须选择移动距离最小的有效候选位置；由任务 2 覆盖。
- 候选位置在限制前可容纳、但限制后会碰到 Dock 可用边界时，不能落入不安全区域；由任务 2 覆盖。
- 固定详情已打开时切换紧凑度，必须保持左上锚点并留在屏幕内；由任务 3 覆盖。
- 指针在收起延迟期间从小组件移入临时详情时，详情必须保持打开；由任务 4 覆盖。
- 样本足够但最后一次消耗突增时，必须显示“不稳定”，不能给出低可信度具体时间；由任务 5 覆盖。

---

## 文件职责

| 文件 | 职责 |
| --- | --- |
| `Sources/WidgetPresentation.swift` | 透明度/紧凑度枚举和缩放布局度量。 |
| `Sources/WidgetPlacementResolver.swift` | 纯拖动结束吸附、碰撞避让和屏幕限制。 |
| `Sources/HoverDetailController.swift` | 与计时器实现解耦的临时/固定悬停状态机。 |
| `Sources/WidgetPreferences.swift` | 持久化透明度和紧凑度选择。 |
| `Sources/WidgetMenu.swift` | 外观子菜单和勾选状态。 |
| `Sources/App.swift` | 窗口快照、位置解析/悬停集成、框架应用和展示状态下发。 |
| `Sources/QuotaView.swift`、`Sources/LargeQuotaView.swift`、`Sources/QuotaDetailsView.swift` | 缩放度量、透明度和可信度渲染。 |
| `Sources/QuotaForecast.swift` | 仅 5 小时窗口的预测结果和可信度分类。 |
| `Tests/*` | 模型、菜单、布局、外观、预测、控制器和文档检查。 |

### 任务 1：展示偏好与布局度量

**文件：** 新增 `Sources/WidgetPresentation.swift`、`Tests/WidgetPresentationTests.swift`；修改 `Sources/WidgetPreferences.swift`、`Tests/WidgetPreferencesTests.swift`、`Scripts/test.sh`。

**接口：**

- `WidgetOpacityPreset`：`opaque`、`translucent`、`light`，带 `alpha: CGFloat`；
- `WidgetDensityPreset`：`standard`、`compact`、`minimal`，带 `scale: CGFloat`；
- `WidgetLayoutMetrics.init(density:)`：提供缩放后的面板尺寸、圆环半径、字体和间距；
- 扩展 `WidgetPreferences`，支持 `opacityPreset`、`densityPreset`、`load(from:)` 与 `save(to:)`。

- [ ] 先写失败测试：默认预设、UserDefaults 往返、非法值恢复、精确 alpha/scale 值以及所有缩放尺寸为正。
- [ ] 运行对应编译目标，确认因新预设和度量不存在而失败。
- [ ] 实现展示枚举、布局度量和偏好持久化；保留既有尺寸、方向、显示范围和历史默认值。
- [ ] 重新运行偏好与度量测试，确认默认、恢复、持久化和精确预设值均通过。
- [ ] 提交：`feat: add widget presentation presets`。

### 任务 2：纯拖动结束位置解析器

**文件：** 新增 `Sources/WidgetPlacementResolver.swift`、`Tests/WidgetPlacementResolverTests.swift`；修改 `Scripts/test.sh`。

**接口：**

- 使用任务 1 的 `WidgetLayoutMetrics`；
- 提供 `WidgetPlacementResolver.resolve(panelFrame:screenFrame:codexFrames:occupiedFrames:) -> CGRect`。

- [ ] 先写失败测试：四个 8 点边缘候选、28 点阈值、最短移动距离决策、被占用边缘的平移、无可用区间时拒绝、Dock 可用区域限制和不吸附回退。
- [ ] 运行位置解析测试，确认因解析器不存在而失败。
- [ ] 实现 `WidgetPlacementResolver`：从最近的有效 Codex 窗口生成候选位置；沿已选边缘移动碰撞候选到最近可容纳区间；选取终点移动距离最小的候选位置。此文件只能使用 CoreGraphics 矩形，不能读取全局窗口 API。
- [ ] 重新运行位置解析测试，确认所有边缘、占用窗口、不安全边界和回退场景通过。
- [ ] 提交：`feat: resolve drag-end widget placement`。

### 任务 3：在应用中应用外观预设与位置解析

**文件：** 修改 `Sources/App.swift`、`Sources/QuotaView.swift`、`Sources/LargeQuotaView.swift`、`Sources/QuotaDetailsView.swift`、`Sources/WidgetMenu.swift`；修改 `Tests/MenuTests.swift`、`Tests/LayoutTests.swift`、`Tests/AppearanceCheck.swift`、`Tests/ControllerTests.swift`。

**接口：**

- 使用任务 1–2 的 `WidgetLayoutMetrics` 与 `WidgetPlacementResolver`；
- 在 `QuotaView` 添加 `onDragFinished: (() -> Void)?`；
- 三个视图增加 `metrics: WidgetLayoutMetrics` 和 `contentOpacity: CGFloat`。

- [ ] 先写失败测试：外观子菜单标题与勾选、每种紧凑度的活动框架变化、两个面板的 alpha 下发、预设切换时锚点保持、拖动结束时只调用一次吸附且不持续移动。
- [ ] 运行受影响的菜单、布局和控制器目标，确认外观动作、度量下发和拖动结束回调缺失而失败。
- [ ] 集成预设与位置解析：新增两个外观子菜单；不使用图层变换；仅在 `onDragFinished` 时快照可见普通级别的 Codex/其他窗口并解析一次最终框架；缩放保持保存的左上锚点，再限制到可见区域。
- [ ] 重新运行展示集成测试，确认菜单、几何、透明度、位置和既有显示范围行为通过。
- [ ] 提交：`feat: apply widget presentation and snap placement`。

### 任务 4：临时悬停详情状态

**文件：** 新增 `Sources/HoverDetailController.swift`、`Tests/HoverDetailControllerTests.swift`；修改 `Sources/App.swift`、`Sources/QuotaView.swift`、`Sources/QuotaDetailsView.swift`、`Tests/ControllerTests.swift`、`Scripts/test.sh`。

**接口：**

- `HoverDetailState`：`closed`、`transient`、`pinned`；
- `HoverDetailController`：`pointerEnteredWidget()`、`pointerExitedWidget()`、`pointerEnteredDetail()`、`pointerExitedDetail()`、`dragStarted()`、`togglePinned()` 和 `close()`；
- `QuotaApp` 根据状态转换打开既有大组件卡片内详情或小组件相邻详情面板。

- [ ] 先写失败状态机测试：可控调度器验证 350 毫秒打开、250 毫秒收起、组件与详情间移动、固定状态、拖动取消、切换布局清理和隐藏清理。
- [ ] 运行控制器测试，确认状态机和调度器接缝不存在而失败。
- [ ] 实现纯悬停控制器和 AppKit 适配：通过注入调度闭包管理计时器；视图只转发跟踪区域事件；临时详情不能让应用变成 key。
- [ ] 重新运行悬停与控制器测试，确认所有状态转换和既有点击固定行为通过。
- [ ] 提交：`feat: show transient quota details on hover`。

### 任务 5：预测可信度模型与渲染

**文件：** 修改 `Sources/QuotaForecast.swift`、`Sources/QuotaView.swift`、`Sources/LargeQuotaView.swift`、`Sources/QuotaDetailsView.swift`；修改 `Tests/ForecastTests.swift`、`Tests/LayoutTests.swift`、`Tests/AppearanceCheck.swift`。

**接口：**

- `ForecastConfidence`：`high`、`medium`、`low`；
- 将 `QuotaForecast` 调整为携带结果 `outcome`（`collecting`、`unstable`、`willNotDeplete`、`depletedAt(Date)`）和可选 `confidence`；
- 保留 `QuotaForecasts.fiveHour`；`QuotaForecasts.week` 始终为 collecting，且绝不渲染用尽预测。

- [ ] 先写失败预测与渲染测试：高（12/20/15%）、中（8/15/25%）、低（6/10/35%）可信度；末次突增不稳定；样本不足/零消耗收集；重置清理；不预测一周；所有可信度都有文字与颜色点。
- [ ] 运行预测与布局测试，确认缺少可信度模型和 UI 标签而失败。
- [ ] 实现可信度分类：使用设计定义的滚动稳健、近期稳健和近期首尾三种速率；以样本/跨度/最大差异选择最高可达档位，否则返回不稳定或收集中；仅在分类通过时使用近期首尾速率预测。
- [ ] 在大组件和小组件详情卡片渲染文字加颜色点；保持“消耗速率不稳定，暂不预测”和“本周期内不会用尽”独立表达。
- [ ] 重新运行预测、布局和外观测试，确认所有可信度档位通过且任务 UI 没有回归。
- [ ] 提交：`feat: show forecast confidence`。

### 任务 6：文档、完整验证与本地安装包

**文件：** 修改 `README.md`、`README.zh-CN.md`、`Tests/DocumentationCheck.sh`；验证 `Scripts/test.sh`、`Scripts/build.command` 和公开源码检查。

- [ ] 更新两份 README 与文档检查，说明仅拖动结束吸附、避让范围、精确预设、悬停时间、可信度含义与刻意排除项；保留“不监控任务”的保证。
- [ ] 运行 `zsh Tests/DocumentationCheck.sh`，确认中英文覆盖通过。
- [ ] 运行 `zsh Scripts/test.sh`、`zsh Tests/PublicTreeCheck.sh` 和 `zsh Scripts/check-public-tree.sh`；如果图形会话不可用，明确记录限制。
- [ ] 运行 `zsh Scripts/build.command`，再对 `outputs/QuotaRings` 执行 `lipo -archs`、`codesign --verify --deep --strict` 和 `unzip -tq`；确认同时具有 arm64 与 x86_64、临时签名有效、ZIP 有效。
- [ ] 提交：`docs: explain widget presentation controls`。

## 自检

- 任务 1–3 覆盖可保存视觉预设与仅拖动结束的吸附/避让。
- 任务 4 覆盖临时与固定详情及生命周期清理。
- 任务 5 覆盖全部可信度阈值，并保持只预测 5 小时额度。
- 任务 6 覆盖双语文档、公开源码边界、验证和安装包。
- 每个审查重点都由所列任务在实现前的失败测试覆盖。
