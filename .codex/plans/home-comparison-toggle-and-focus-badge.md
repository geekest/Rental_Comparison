# 首页对比切换与重点标签可读性优化

## 1. 任务目标

修复首页房源卡片中“加入对比”进入已选状态后不可再次点击的问题，并提升图片背景上的“重点考虑”标签可读性。完成后，用户可以在首页反复点击同一个按钮加入或取消房源；重点标签在不同照片上都能清楚识别。

## 2. 当前状态

- `Rental_Comparison/ListingsView.swift` 的 `ListingCard` 在已加入对比时显示“已加入对比”，但按钮是空操作且被禁用。
- `AppStore.toggleComparison(_:)` 已支持加入和取消两种分支，取消逻辑当前只在对比页入口可用。
- `ListingCardCover` 使用通用 `StatusPill` 叠加在图片右上角；其低透明度警示色背景在浅色照片上对比不足。
- 既有 UI 测试只验证加入后的文案，没有验证首页再次点击能够取消。

## 3. 目标状态

- 首页卡片的对比按钮始终可点击，文案与样式随状态变化。
- 点击“已加入对比”后立即取消选择，首页徽标数量和按钮状态同步更新。
- “重点考虑”标签具备稳定的背景、边框和阴影，不只依赖文字颜色表达状态。
- 既有对比上限、详情跳转和其他卡片操作不受影响。

## 4. 范围边界

### 本次包括

- 首页房源卡片对比按钮状态切换。
- 首页图片卡片“重点考虑”标签视觉优化。
- 相关 UI 回归测试与构建验证。
- 两个问题分别提交 commit 并推送当前分支。

### 本次不包括

- 修改对比页的交互规则。
- 修改对比数量上限或决策模型。
- 修改图片裁切、图片存储或房源详情页图片管理。

## 5. 影响文件

- `Rental_Comparison/ListingsView.swift`：卡片按钮交互与重点标签。
- `Rental_ComparisonUITests/RentalComparisonUITests.swift`：首页加入/取消对比回归。
- `.codex/plans/home-comparison-toggle-and-focus-badge.md`：执行记录。

## 6. 执行里程碑

### Milestone 1：修复首页对比切换

实现统一的加入/取消按钮动作，补充 UI 自动化验证，完成后单独提交并推送。

### Milestone 2：优化重点标签

为图片背景上的重点标签增加稳定底衬、边框、阴影和明确的图标/文字层级，完成后单独提交并推送。

### Milestone 3：最终验证

运行构建和相关 UI 测试，检查差异、分支状态及两个提交均已同步远端。

## 7. 进度记录

- [x] 检查工作树与现有实现
- [x] 读取 SwiftUI 与 Apple 设计规范
- [x] 修复首页对比切换并测试
- [x] 提交并推送问题 1
- [x] 优化重点标签并测试
- [x] 提交并推送问题 2
- [x] 完成最终验证与复盘

## 8. 新发现与意外情况

- 发现：SwiftUI 不支持通过三元表达式切换不同的 `ButtonStyle` 类型。
- 影响：按钮状态样式需要在 `if/else` 分支中分别声明。
- 处理方式：保留两个分支的同一动作语义和 accessibility identifier，只分别使用 bordered / borderedProminent 样式。
- 发现：Simulator 使用 `-uiTesting` 启动时一次截屏出现黑屏。
- 影响：无法用该次截图判断标签视觉效果。
- 处理方式：改用普通启动参数重新安装启动，截图正常显示并确认标签可读。

## 9. 决策记录

### Decision：复用现有 `toggleComparison`

选择：只调整卡片按钮的可用状态与显示，不新增状态模型或重复业务逻辑。

原因：`AppStore.toggleComparison(_:)` 已经同时实现加入、取消和数量上限判断。

影响：变更范围小，能保持首页、对比页使用同一套状态源。

### Decision：重点标签使用独立高对比度样式

选择：不修改全局 `StatusPill`，为图片上的重点标签使用深色半透明底衬、白色文字、强调色图标和轻微阴影。

原因：其他页面的状态胶囊需要保留原有语义和颜色；图片叠加标签需要针对背景单独处理。

## 10. 验证计划

- `xcodebuild ... build`：确认原生 App 编译成功。
- `xcodebuild ... -only-testing:Rental_ComparisonUITests/RentalComparisonUITests/testListingCardCanJoinComparisonAndOpenDetails test`：确认首页加入后再次点击可取消，并可继续打开详情。
- `xcodebuild ... -only-testing:Rental_ComparisonUITests/RentalComparisonUITests/testMainTabsOpenDecisionScreens test`：确认导航和首页基本流程不回归。
- `git diff --check`：确认无空白错误。
- 分别检查两个 commit 与 origin 分支 SHA。

## 11. 风险与回滚

- 风险：按钮样式重构可能影响 UI 自动化定位；保留原有 accessibility identifier。
- 风险：图片标签底衬若过重会遮挡照片；控制为胶囊区域，不改变图片裁切。
- 回滚：两个问题分别独立提交，可按问题单独回滚。

## 12. 最终结果与复盘

- 问题 1：首页对比按钮不再禁用，加入和取消共用 `AppStore.toggleComparison(_:)`，保留原有数量上限和 accessibility identifier。
- 问题 2：图片上的“重点考虑”标签改为独立高对比度样式，包含深色半透明底衬、白字、黄星、描边和阴影。
- 验证：问题 1 定向 UI 测试通过；问题 2 构建、首页 Simulator 截图和基础导航 UI 测试通过；`git diff --check` 通过。
- 两个问题分别使用独立 commit 并已推送至 `origin/codex/listing-import-share-extension`：问题 1 为 `03c973a`，问题 2 为 `3f8daa7`。
