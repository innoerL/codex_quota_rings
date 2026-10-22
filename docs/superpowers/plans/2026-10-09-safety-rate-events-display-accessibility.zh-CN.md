# 安全使用速率、事件记录、显示规则与无障碍实施计划

> **面向执行代理：** 必须逐项执行并在每一步使用测试驱动开发；所有步骤均使用复选框跟踪。

**目标：** 为 Quota Rings 加入被动式五小时安全使用速率、私有额度事件、任务汇总、更细的显示行为和可访问的视觉反馈。

**架构：** 新增独立的安全速率、任务汇总、额度事件和显示规则模型。`QuotaApp` 负责它们的生命周期，并把派生状态发布给三个现有 AppKit 界面；视图只渲染，不持久化。历史与事件分别保存为本地 JSON 文件，共用两档保留策略。

**技术栈：** Swift 5、AppKit、Foundation、UserDefaults、Application Support 中的 JSON 文件、现有 Swift 可执行测试。

**对应设计说明：** `docs/superpowers/specs/2026-10-09-safety-rate-events-display-accessibility-design.md`

## 全局约束

- 应用保持原生 AppKit 架构，除现有的本地 Codex app-server 连接外不访问网络。
- 不发送 macOS 通知；安全使用速率仅在组件内提示。
- 只持久化额度样本和固定额度事件种类；绝不保存任务标题、任务 ID、账号数据、原始协议消息或 Codex 自由文本。
- 趋势记录只能选择本次会话 30 分钟或本地保留 5 小时。
- 旧的 `local24Hours` 与 `local7Days` 偏好迁移为 `local5Hours`，并裁剪为最近五小时。
- 安全指导只基于五小时额度，能识别重置，且必须以文字和图标表达状态，不能只依赖颜色。
- 保持既有任务跳转和自动刷新行为。

## 审查重点

- 时钟变化、未来时间样本和重复时间戳不能产生误导性的安全速率；由任务 2 覆盖。
- 额度重置必须清除旧速率窗口，且只写入一次重置事件；由任务 2、3 覆盖。
- 从本地保留切回会话模式必须删除两份持久化文件，包括删除失败场景；由任务 1 覆盖。
- 锁定显示必须覆盖范围隐藏规则，但退出与应用终止仍必须隐藏组件；由任务 4 覆盖。
- 即使颜色不可用，VoiceOver 也必须传达危险状态与任务汇总；由任务 5 覆盖。

---

## 文件职责

| 文件 | 职责 |
| --- | --- |
| `Sources/QuotaHistory.swift` | 两档保留、偏好迁移与样本裁剪。 |
| `Sources/QuotaSafetyRate.swift` | 可识别重置的五小时速率计算与状态。 |
| `Sources/TaskSummary.swift` | 从任务状态派生的内存汇总。 |
| `Sources/QuotaEvent.swift` | 固定额度事件模型、去重存储与保留策略。 |
| `Sources/WidgetDisplayRules.swift` | 保存显示规则并提供可验证的优先级逻辑。 |
| `Sources/WidgetPreferences.swift`、`Sources/WidgetMenu.swift` | 偏好与菜单选项。 |
| `Sources/App.swift` | 模型生命周期、状态发布、Option 点击、显示锁定和可见性判断。 |
| 三个视图文件 | 安全速率、汇总、事件、无障碍和对比度渲染。 |

### 任务 1：保留策略迁移与显示规则偏好

**文件：** 修改 `QuotaHistory.swift`、`WidgetPreferences.swift`、`WidgetMenu.swift`；新增 `WidgetDisplayRules.swift` 和对应测试；更新历史、偏好、菜单测试与 `Scripts/test.sh`。

**产出接口：**

- `HistoryRetention.session30Minutes` 与 `HistoryRetention.local5Hours`；
- `WidgetDisplayRules(hideInFullScreen: Bool = true, lockDisplay: Bool = false)`，支持 `load(from:)` 与 `save(to:)`；
- `WidgetDisplayRules.shouldShow(scopeVisible:isFullScreen:) -> Bool`。

- [ ] 先写失败测试：旧偏好迁移、五小时裁剪、会话模式删除记录、规则默认值与无效值恢复。
- [ ] 运行相关目标，确认因缺少新枚举与规则而失败。
- [ ] 实现两档保留、旧值迁移、菜单中的“仅本次 · 30 分钟”“保留 5 小时”、全屏隐藏和锁定显示。
- [ ] 重新运行相关测试并确认通过。
- [ ] 提交：`feat: add five-hour retention and display rules`。

### 任务 2：安全使用速率与任务汇总模型

**文件：** 新增 `QuotaSafetyRate.swift`、`TaskSummary.swift` 及其测试；更新 `Scripts/test.sh`。

**产出接口：**

- `QuotaSafetyState`：`collecting`、`safe`、`caution`、`danger`；
- `QuotaSafetyRate`：当前速率、可持续速率、状态与图标/文字；
- `QuotaSafetyRateEngine.record(_ snapshot: QuotaSnapshot, forecast: QuotaForecast) -> QuotaSafetyRate`；
- `TaskSummary(statuses: [WidgetTaskStatus])`：运行数、刚完成数和中文汇总文案。

- [ ] 先写失败测试：样本不足、安全阈值 110%、警示阈值 111–140%、危险阈值、重置、重复或未来样本和预测提前耗尽。
- [ ] 写失败任务汇总测试：空、仅运行、仅完成、混合状态。
- [ ] 运行测试并确认失败。
- [ ] 实现最近 15 分钟、至少三个且跨两分钟的重置后样本计算；当前速率为已用百分比/小时，可持续速率为剩余百分比/距重置小时数。
- [ ] 运行模型测试并确认通过。
- [ ] 提交：`feat: add safety rate and task summary models`。

### 任务 3：私有额度事件存储

**文件：** 新增 `QuotaEvent.swift` 和测试，更新 `Scripts/test.sh`。

**产出接口：**

- `QuotaEventKind`：重置、速率状态变化、额度阈值、连接恢复；
- `QuotaEvent`：时间、事件种类、可选剩余百分比；
- `QuotaEventStore.record(kind:remainingPercent:at:)`、`events(at:)`、`setRetention(_:at:)`。

- [ ] 写失败测试：编码中没有任务字段、连续同类事件去重、界面最多显示四条、五小时裁剪、会话模式删除事件文件。
- [ ] 运行测试并确认失败。
- [ ] 实现同目录 `quota-events.json`、连续事件去重和时间戳校验。
- [ ] 运行事件与历史测试并确认通过。
- [ ] 提交：`feat: record private quota events`。

### 任务 4：派生状态集成与显示行为

**文件：** 修改 `App.swift`、`WidgetVisibility.swift`、可见性与控制器测试、`Scripts/test.sh`。

- [ ] 先写失败测试：全屏隐藏、锁定显示优先级、Option 点击不改变锁定、重置/速率/阈值/连接恢复事件各只记录一次。
- [ ] 运行相关目标并确认失败。
- [ ] 在 `QuotaApp` 中创建事件存储，记录快照与连接转换，向全部视图发布安全速率、任务汇总、事件和显示规则。
- [ ] 在 `shouldDisplayNow()` 中实现规则优先级，在 `QuotaView.mouseUp` 中区分 Option 点击。
- [ ] 通过既有菜单状态流增加全屏隐藏与锁定显示，且只在内容变化时调整尺寸。
- [ ] 运行可见性、控制器编译和协议测试。
- [ ] 提交：`feat: integrate pace events and display controls`。

### 任务 5：渲染指导、事件与无障碍状态

**文件：** 修改三个组件视图、趋势视图、任务行及布局、外观、任务行测试。

- [ ] 先写失败测试：每张卡都有安全图标与文字、任务汇总位于任务行前、详情至多四条固定文案事件、状态不只依赖颜色、提高对比度与减少动态效果保持可读。
- [ ] 运行布局与外观测试并确认失败。
- [ ] 为紧凑卡片添加简短安全提示；为展开/详情卡片添加速率、事件；根据 macOS 提高对比度与减少动态效果设置渲染。
- [ ] 扩展 VoiceOver 文案，包含额度、安全状态、任务汇总、事件范围与锁定状态。
- [ ] 运行布局、外观与任务行测试，并人工检查五种预览布局无重叠。
- [ ] 提交：`feat: render accessible quota guidance`。

### 任务 6：文档、完整验证与本地安装包

**文件：** 修改 `README.md`、`README.zh-CN.md`、`Tests/DocumentationCheck.sh`；验证测试、构建和公开边界检查。

- [ ] 更新中英文 README，说明被动速率、私有事件、两档保留、显示规则和无障碍；不宣称有通知或远程分析。
- [ ] 更新并运行文档检查。
- [ ] 运行 `zsh Scripts/test.sh`；若图形会话不可用，明确记录该限制。
- [ ] 运行 `zsh Scripts/build.command`，再验证 `lipo -archs`、`codesign --verify --deep --strict` 和 `unzip -tq`。
- [ ] 提交：`docs: describe safety guidance and privacy`。

## 自检

- 所有设计要求都映射到任务 1–5；文档与本地安装包由任务 6 覆盖。
- 后续任务使用的公共类型均由前置任务定义。
- 审查重点分别由任务 1–5 的测试覆盖。
- 每个任务独立可测试，且不会持久化受隐私约束禁止的数据。
