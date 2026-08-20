# 基于 PR11 重构租房决策需求

## 1. 任务目标

将旧分支的 7 个提交所表达的需求，重新移植到 PR11 的新决策模型上，不保留旧 `AppState / RentalTask / Listing` 作为第二套业务真相源。

完成后用户应能：

- 按“选房 → 待确认 → 对比决策”的顺序使用底部导航；
- 在待确认页直接完成核实或进入房源详情；
- 进入房源详情后直接编辑字段，取消“完整信息”二次入口；
- 使用设置 tab 管理常用偏好；
- 创建、编辑、切换多个独立选房任务；
- 在候选卡片上看到正确的加入对比按钮颜色；
- 在每个 SwiftUI view 文件中使用 Xcode `#Preview`。

## 2. 当前状态

- 当前分支和 `main` 同为 PR11 提交 `13f43c0`。
- PR11 已将业务真相源迁移为 `DecisionAppState`，核心对象为 `Hunt / Option / Fact / Evidence / Criterion / DecisionUnknown / VerificationTask`。
- `DecisionLegacyProjection` 仅为旧页面提供兼容投影，不能继续扩展为第二套持久化模型。
- 当前 tab 为“选房 / 对比 / 待确认”，待确认页已支持部分验证任务，但顺序不符合需求，且没有设置 tab。
- 当前详情页仍通过 `ListingEditorView` sheet 编辑；候选卡片已有“加入对比”和“查看详情”，样式需按需求调整。
- PR11 的 `DecisionPersistenceClient` 和迁移层负责本地 v2 数据；多任务必须在该持久化边界内设计。

## 3. 目标状态

- `AppTab` 顺序为 `hunt → verify → comparison → settings`。
- 待确认页继续使用 PR11 的 `unknowns / verificationTasks`，但每项可在当前页完成确认、跳转到任务详情或房源详情。
- 详情页基于 `Option` 与 `Fact` 的编辑入口直接修改 v2 状态；旧 `Listing` 只作为展示投影。
- 新增 `DecisionPreferences` 或等价的 v2 配置字段，保存默认城市/货币/居住月数/显示偏好等常用设置。
- `DecisionAppState` 支持多个 Hunt 工作区及当前 Hunt；旧单 Hunt v2 数据可以无损迁移为一个任务。
- 每个 View 文件有 fixture-backed `#Preview`，不依赖真实持久化或网络。

## 4. 范围边界

### 本次包括

- PR11 原生 SwiftUI App、v2 数据模型、迁移、持久化、页面和测试。
- 旧 7 个提交中的用户可见需求和预览要求。
- 必要的 v2 数据迁移测试和 UI 流程测试。

### 本次不包括

- Web MVP、云同步、账号、网络接口和第三方依赖。
- 恢复旧分支的 `AppState / RentalTask / Listing` 持久化改造。
- 修改 PR11 已完成的视觉设计系统，除非为新交互必须接入。

## 5. 影响文件

- `DecisionModels.swift`、`DecisionPersistence.swift`、`DecisionModelMigration.swift`：多任务和偏好持久化。
- `AppStore.swift`：当前 Hunt、任务切换、v2 字段编辑和待确认操作。
- `RootView.swift`、`VerifyView.swift`、`VerificationTaskDetailView.swift`：导航顺序与待确认入口。
- `ListingsView.swift`、`ListingEditorView.swift`、`DecisionLegacyProjection.swift`：详情字段直接编辑和 v2 写回。
- `ComparisonView.swift`、`WarmDesign.swift`：卡片按钮和当前任务展示。
- 新增 `SettingsView.swift` 或 v2 设置组件。
- `Rental_ComparisonTests/`、`Rental_ComparisonUITests/`：迁移、任务切换、详情编辑、tab 顺序和预览编译验证。

## 6. 执行里程碑

### Milestone 1：梳理 v2 工作区边界

- 找出 `DecisionAppState` 的读写入口和所有 `state.hunt` 假设。
- 确定多 Hunt 的持久化 envelope 和迁移方案。
- 用单元测试锁定旧 v2 单 Hunt JSON 的兼容行为。

### Milestone 2：多任务与偏好

- 在 v2 状态中增加 Hunt 集合、当前 Hunt ID 和偏好。
- AppStore 提供创建、编辑、切换、删除任务及设置更新。
- 验证切换后选房、待确认、对比页面只读取当前 Hunt。

### Milestone 3：决策链路与详情编辑

- 调整 tab 顺序，复用 PR11 待确认引擎并补充直接确认入口。
- 把 Option/Fact 的可编辑字段放入详情页，移除“完整信息”二次编辑路径。
- 保留旧投影仅用于兼容现有页面，避免写入旧模型。

### Milestone 4：按钮、设置与预览

- 完成设置 tab 和候选卡片按钮样式。
- 为所有 View 文件补齐 fixture-backed `#Preview`。
- 更新 UI 测试和可访问性标识。

### Milestone 5：验证与交付

- 运行 `xcodegen generate`、Simulator build、unit test、UI test 和 `git diff --check`。
- 按用户要求每个需求点单独提交；不直接覆盖 PR11 的历史提交。
- 更新计划复盘，并在用户要求时推送和创建 PR。

## 7. 进度记录

- [x] 确认当前分支已基于 PR11
- [x] 保留旧 7 个提交为本地备份分支
- [x] 阅读 PR11 新模型、迁移、导航和验证页面
- [x] 完成 v2 多任务与偏好设计
- [x] 完成待确认链路与详情字段编辑
- [x] 完成设置、按钮和预览
- [x] 补充测试
- [x] 运行完整验证
- [x] 完成复盘

## 8. 新发现与意外情况

- 发现：PR11 的核心状态模型已经替换，旧分支改动不能直接 cherry-pick。
- 影响：需要将需求移植到 v2，而不是恢复旧 `AppState` 作为写入模型。
- 处理方式：保留旧分支备份，只从 PR11 新模型重新实现。
- 发现：PR11 的 UI fixture 已默认将徐汇和静安加入对比。
- 影响：卡片 UI 测试必须横向滑动到普陀房源，才能验证“加入对比”状态。
- 处理方式：改用普陀 fixture，并在测试中先滑动候选卡片列表。
- 发现：Xcode 测试执行期间的诊断收集提示 PATH 中找不到 `simctl`，但构建和测试本身正常执行。
- 影响：不影响本次 Swift 编译、单元测试和已选 UI 测试结果；完整 UI 测试需保留该环境提示。

## 9. 决策记录

### Decision：多任务的持久化边界

选择：扩展 v2 持久化 envelope，使每个任务拥有独立 Hunt、Option、Fact、Evidence 和 VerificationTask 集合，AppStore 暴露当前工作区。

原因：保持 PR11 的事实、证据和待确认任务关联关系，避免用旧投影拼装多任务。

备选方案：只存任务摘要并复用一个全局状态；会导致切换任务时房源和证据串线。

## 10. 验证计划

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ... build`
- `xcodebuild ... -only-testing:Rental_ComparisonTests test`
- `xcodebuild ... -only-testing:Rental_ComparisonUITests test`
- 单元测试：单 Hunt 迁移、多 Hunt round-trip、任务切换隔离、待确认写回。
- UI 测试：tab 顺序、待确认直接操作、详情字段编辑、任务创建切换、卡片按钮样式标识。
- `git diff --check` 和逐文件 diff 审查。

## 11. 风险与回滚

- 多 Hunt 持久化会影响 PR11 v2 数据格式；必须保留旧单 Hunt 解码迁移。
- 详情页如果通过旧投影写回，可能丢失 Fact 的来源和验证状态；写回必须经 v2 AppStore API。
- 任务切换必须清理或重建导航中的选中项，避免跨任务打开房源。
- 回滚方式：按需求点 revert 新提交；旧 7 个提交仍可从本地备份分支查阅，不作为新基线。

## 12. 结果复盘

- 已从 PR11 `13f43c0` 继续实现多任务、偏好设置、决策链路、待确认操作、详情内联编辑、候选卡片按钮和 SwiftUI 预览。
- 已补充多任务隔离、偏好 round-trip、tab 流程、详情编辑入口和候选卡片加入对比的测试。
- 已完成 `xcodegen generate`、Simulator build、38 个单元测试和候选卡片单项 UI 测试；单元测试全部通过，候选卡片单项 UI 测试通过。
- 完整 UI 测试中除早期未处理的横向滚动定位问题外，其余测试通过；修正后目标 UI 测试已单独通过。
