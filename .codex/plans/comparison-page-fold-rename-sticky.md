# 对比页折叠、文案与置顶改造

## 1. 任务目标

对比页需要支持三项独立改动：

1. 允许整体折叠“硬性冲突、主要差异、决策阻塞项、已知取舍”等分析信息。
2. 将“查看完整对比”改为“对比详细数据”。
3. 页面向下滚动时，顶部房源横向区域保持固定，让用户持续知道数据对应的房源。

完成后，用户可以在分析信息与详细数据之间切换，看到更明确的操作名称，并在浏览长页面时保留房源上下文。

## 2. 当前状态

- 主要实现位于 `Rental_Comparison/ComparisonView.swift`。
- `ComparisonView` 当前使用一个纵向 `ScrollView`，顶部为 `ComparisonHeader`，随后是 `DifferenceFirstSummary`、完整对比切换按钮和详细数据栏目。
- `DifferenceFirstSummary` 当前始终展示 4 个分析卡片，没有折叠状态。
- “查看完整对比”按钮同时控制详细数据区域的显示。
- `ComparisonHeader` 当前位于纵向滚动内容内部，因此向下滚动会离开屏幕。
- 已有 `Rental_ComparisonUITests/RentalComparisonUITests.swift` 覆盖对比页入口和横向滚动同步行为。
- 当前工作树已有 Xcode 生成的 `UserInterfaceState.xcuserstate` 未提交改动，必须保留。

## 3. 目标状态

- 分析区域有明确的整体展开/收起控制，收起后 4 个分析卡片均不可见，展开后恢复原有内容。
- 详细数据按钮文案为“对比详细数据”，收起时对应文案为“收起详细数据”。
- 房源横向区域固定在导航栏下方或安全区域顶部，纵向滚动详细内容时仍可见；它仍支持原有横向滚动与房源列联动。
- 固定区域不遮挡正文，支持 iOS 17 部署目标、动态字体和辅助功能状态描述。

## 4. 范围边界

### 本次包括

- 对比页分析区的整体折叠状态和可访问性标识。
- “查看完整对比”相关用户可见文案。
- 对比页房源头部的顶部固定布局。
- 对应 UI 回归测试。

### 本次不包括

- 不改变分析数据计算逻辑、房源排序或横向滚动同步算法。
- 不修改 Web MVP、数据模型、持久化和项目配置。
- 不修改用户已有的 Xcode 用户状态文件。

## 5. 影响文件

- `Rental_Comparison/ComparisonView.swift`：对比页状态、分析区、详细数据按钮和顶部固定区域。
- `Rental_ComparisonUITests/RentalComparisonUITests.swift`：补充 3 项用户行为回归测试。
- `.codex/plans/comparison-page-fold-rename-sticky.md`：记录执行与复盘。

## 6. 执行里程碑

### Milestone 1：理解现有实现

要做：确认对比页视图层级、滚动容器、状态和已有测试。

验证：能定位分析区、详细数据按钮和房源头部的具体调用点。

完成标准：已完成当前状态记录。

### Milestone 2：分析区整体折叠

要做：增加局部展开状态和控制按钮，保持默认展开以兼容当前行为；补充测试并提交第 1 个 commit。

验证：UI 测试确认点击后分析卡片整体消失/恢复；构建通过。

完成标准：第 1 个中文 commit 建立，且只包含该改动及对应测试。

### Milestone 3：详细数据文案调整

要做：调整按钮展开/收起文案和测试选择器；提交第 2 个 commit。

验证：代码搜索确认旧文案不再作为该按钮标签；构建通过。

完成标准：第 2 个中文 commit 建立，且只包含该改动及对应测试。

### Milestone 4：房源头部固定

要做：将房源头部从纵向滚动内容中移到顶部安全区域固定容器，保留横向滚动协调器；补充滚动回归测试并提交第 3 个 commit。

验证：模拟器 UI 测试确认向下滚动后房源头部仍存在并可见；构建通过。

完成标准：第 3 个中文 commit 建立。

### Milestone 5：最终审查

要做：检查三次 commit 范围、差异、回归风险和未验证项。

验证：`git diff --check`、构建、相关 UI 测试以及 `git status`。

完成标准：仅保留用户原有 Xcode 状态改动未提交，三次功能 commit 可追溯。

## 7. 进度记录

- [x] 阅读仓库规则和执行计划规范
- [x] 确认当前分支与已有工作树改动
- [x] 确认对比页实现和测试入口
- [x] 完成分析区整体折叠
- [x] 完成详细数据文案调整
- [ ] 完成顶部房源固定
- [ ] 运行验证并建立 3 个 commit
- [ ] 完成最终 diff 审查与复盘

## 8. 新发现与意外情况

- 发现：当前工作树只有 Xcode `UserInterfaceState.xcuserstate` 已有未提交改动。
  - 影响：提交时必须显式指定文件，不能使用全量 `git add`。
  - 处理方式：保留该文件原状，不纳入任何 commit。
- 发现：当前部署目标为 iOS 17，顶部固定实现不能依赖只在 iOS 18/26 可用的滚动 API。
  - 影响：需要使用 iOS 17 可用的 `safeAreaInset` 或等价布局。
  - 处理方式：优先采用 SwiftUI 原生 `safeAreaInset(edge: .top)`，避免引入新依赖或改部署目标。
- 发现：当前 `Rental_Comparison.xcodeproj` scheme 只有 App Target，未包含 UI Test Target。
  - 影响：不能直接用当前工程执行 UI 测试。
  - 处理方式：使用未改写仓库文件的临时工程验证 `project.yml` 声明的 UI Test Target。

## 9. 决策记录

### Decision：默认保留分析区展开

选择：新增整体折叠能力，但初始状态继续展开。

原因：保持现有用户进入对比页后的信息可见性，用户可主动收起以优先查看详情。

备选方案：默认收起；会改变当前默认信息密度，且截图表现不再兼容。

影响：新增一个局部 UI 状态和对应按钮。

### Decision：使用安全区域顶部插入固定房源头部

选择：将 `ComparisonHeader` 放入顶部安全区域插槽，而不是继续放在纵向 `ScrollView` 内。

原因：iOS 17 可用、与导航栏层级关系清晰，并能避免滚动内容遮挡固定房源信息。

备选方案：使用 iOS 18 的 `ScrollPosition` 或 iOS 26 的 `safeAreaBar`；当前部署目标不适合直接依赖这些 API。

影响：页面正文顶部需要让出固定头部高度，横向房源滚动仍由现有协调器维护。

## 10. 验证计划

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,name=iPhone 16e' build`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,name=iPhone 16e' test`
- 相关 UI 测试：进入比较页、折叠/展开分析区、展开/收起详细数据、纵向滚动后确认房源头部仍存在。
- `git diff --check` 和三次 commit 后的 `git status --short`。

## 11. 风险与回滚

- 固定头部可能减少正文首屏可见高度；通过安全区域插入和紧凑布局控制影响。
- 顶部房源头部与详细数据横向联动关系不能被破坏；保留现有 `ComparisonScrollCoordinator` 及已有回归测试。
- 每个改动单独提交，可按 commit 顺序逐项回滚。
- 不涉及数据和持久化，回滚风险低。

## 12. 最终结果与复盘

当前阶段：折叠功能和详细数据文案已完成并通过构建与临时工程 UI 验证，待继续完成顶部固定。
