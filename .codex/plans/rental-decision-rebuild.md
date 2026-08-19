# Rental Decision System iOS 重构

## 1. 任务目标

将已运行的 iOS v1 从房源字段整理工具重构为以 Decision Readiness 为核心的本地优先租房决策系统。完成后，用户可捕获候选、追溯事实与证据、解决高影响未知、执行验证任务、查看差异与取舍，并完成可撤回的最终选择。

## 2. 当前状态

当前分支为 `codex/ios-card-layout`，基线为 `1393d02`。v1 使用 `AppState(version: 1)`、`RentalTask` 与 `Listing`，`state-v1.json` 原子保存。现有三 Tab 为房源、对比、条件；已有成本、看房、淘汰/恢复、最终确认和测试。

## 3. 目标状态

v2 使用 Hunt、Option、Fact、Evidence、Unknown、VerificationTask、Criterion 与扩展 DecisionEvent，升级为可回退 v1 → v2 本地迁移。主导航为选房、对比、待确认；默认比较为 difference-first，最终选择受 Decision Readiness Gate 约束。

## 4. 范围边界

### 本次包括

- 附件 `rental_decision_rebuild_plan.md` 的 P0、数据迁移、测试和 iOS 运行验收。

### 本次不包括

- P1 的 Share Extension、自动提取、Provider Adapter、多人、地图和远程 AI，以及服务器、账户、云同步、支付和跨端同步。

## 5. 影响文件

- `CONTEXT.md`、`docs/product/`、`docs/specs/`、`docs/adr/`：v2 权威定义与迁移决策。
- `Rental_Comparison/`：领域、存储、决策引擎和 SwiftUI 页面逐 Phase 演进。
- `Rental_ComparisonTests/`、`Rental_ComparisonUITests/`：迁移、未知项、Readiness、对比与主流程回归。
- `PLAN.md`：阶段进度与验证证据。

## 6. 执行里程碑

1. Phase 0：更新权威文档、SPEC-002 与 ADR-0003；验证文档引用和 git diff。
2. Phase 1：实现 v2 模型、迁移与存储回退；以 fixture 覆盖数据和媒体兼容。
3. Phase 2-3：重组导航与 Hunt Home，实现 Next Action、Readiness、Quick Capture 与渐进详情。
4. Phase 4-7：实现 Unknown、Verification、Difference-first Compare 与最终 Gate。
5. Phase 8-10：移除 Core 地区硬编码，完成完整自动化和真机验收记录。

## 7. 进度记录

- [x] 阅读附带重建计划、仓库规则和 v1 实现。
- [x] Phase 0：更新 v2 权威文档、规格和迁移 ADR。
- [x] Phase 1：v2 模型、迁移与存储测试；`AppStore` 已切换至 v2，并通过兼容投影维持既有页面。
- [x] Phase 2：导航与 Hunt Home；一级导航改为选房 / 对比 / 待确认，补充 Readiness、Next Action 与待确认聚合页。
- [x] Phase 3：Quick Capture 与 Progressive Detail；名称可单独保存，缺失月租保持未知，截图与照片以不同 Evidence 类型保存，详情页展示事实来源与确认状态。
- [x] Phase 4：Unknown Engine；高影响费用、月租、硬性条件和计划看房的夜间噪音未知项已显式建模并可自动关闭，用户可手动添加待确认事项。
- [x] Phase 5：VerificationTask 与 Viewing Mode；Unknown 自动生成询问、检查或现场观察任务；任务结果可保存文字/照片 Evidence、回写观察 Fact、关闭 Unknown 并记录事件。
- [x] Phase 6：Difference-first Compare；先展示硬冲突、关键差异、阻塞项和已知取舍，完整矩阵按需展开。
- [x] Phase 7：Decision Readiness Gate 与最终决策；最终确认呈现月租/通勤取舍、风险备注、阻塞和逐条事实证据，且不再通过兼容层丢失 v2 状态。
- [x] Phase 8：地区模板与货币边界；中国大陆默认值仅由模板提供，兼容编辑页的面积单位从模板读取，金额使用系统 Locale 且调用方须传入货币代码，跨币种比较明确提示。
- [x] Phase 9：完整 XCTest / XCUITest 验证；iPhone 16e Simulator 共 35 项通过，含按候选进入现场验证并一键记录结果的 UI 路径。
- [~] Phase 10：真机产品验收；iPhone 17 已构建、安装和启动，尚缺少人工完成核心交互的验收记录。
- [ ] 完成最终复盘。

## 8. 新发现与意外情况

- v1 已经把媒体独立保存在 `Media/`，可复用该目录并仅迁移引用。
- v1 的格式化工具固定 `zh_CN`，需在 Phase 8 改为系统 Locale；在此之前不得宣称全球化完成。
- v2 文件必须加入 Xcode Target；首次生成工程后发现新增源文件误落在仓库根目录，已移入正确目录并重新生成工程。后续以实际参与编译的 `project.pbxproj` 为准。
- 在 Phase 2 完成前，旧页面的编辑操作会经兼容投影重建 v2 状态；因此必须优先迁移新页面，避免在过渡期新增只存在于 v2 的编辑能力。
- XcodeBuildMCP 的 Simulator 连接器未继承当前机器的 Xcode 路径，无法直接启动；已改用同一 iPhone 16e 的 `xcodebuild` / XCTest 验证。连接器问题不影响项目构建与测试结果，但本阶段未取得可用的连接器 UI 快照。

## 9. 决策记录

### Decision：先并存 v1 / v2 文件

选择：保留 `state-v1.json`，仅在 v2 原子写入成功后使用 `state-v2.json`。

原因：迁移涉及真实用户本地数据，必须保证失败可恢复。

影响：迁移与回退需有独立测试，不能用清空状态简化错误处理。

## 10. 验证计划

- 每个 Phase 运行 `git diff --check`、iOS Debug build 与相关 XCTest/XCUITest。
- Phase 1 额外验证 v1 迁移、幂等、媒体和失败回退。
- 已完成 Phase 1 验证：iPhone 16e Simulator 单元测试 13 项、UI 测试 3 项全部通过。
- 完成 P0 后运行完整 `xcodebuild test`，并在 iPhone 16e Simulator 检查选房、对比、待确认和最终确认。
- 真机前不将 Simulator 验证表述为真机证据。
- 真机基础证据：2026-08-19，iPhone 17（iOS 26.6.1）使用临时 `DEVELOPMENT_TEAM` 构建、安装、前台启动并保持运行成功；未修改项目签名配置。手工交互尚未验证。
- 真机自动化限制：使用现有 Team 运行真机测试后，31 个 XCTest 已通过；XCUITest Runner 因免费开发者账号在 iPhone 上 3 个可安装 App 名额已满而无法安装。未删除设备上已有 App，工程签名配置未改写。
- 2026-08-19 回归：Unknown / Viewing 闭环、v2 合并保护、地区模板边界和截图来源区分加入后，iPhone 16e Simulator 完整测试共 35 项通过；iPhone 17 重新构建、安装并启动当前 Debug 包成功。

## 11. 风险与回滚

- 最大风险是迁移导致用户数据不可读；保留 v1、原子写 v2 并覆盖失败路径。
- SwiftUI 重组可能影响既有交互；以分 Phase 迁移和 UI 测试降低回归。
- 回滚以停止写入 v2、继续读取 v1 为主；不得删除用户媒体。

## 12. 最终结果与复盘

实施中。每个完成 Phase 在此追加实际修改、验证证据、未验证项和风险。
