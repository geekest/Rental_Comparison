# 对齐 iOS 主线开发文档

## 1. 任务目标

将仓库根部和权威产品文档从“Web MVP 主开发”整理为“原生 iOS 主开发、Web 历史验证”，并记录当前分支之间的真实进度和验证边界。

## 2. 当前状态

- 当前基线：`codex/listing-import-share-extension`，`93233e5`。
- `main` 为 `b79ac84`；设置分支为 `d672a70`；图标分支为 `8545db5`。
- 工作区原有 Xcode `xcuserdata` 未提交改动，本任务不得纳入提交。
- 根部 `README.md`、`AGENTS.md`、`PLAN.md` 与部分产品/规格文档对 Web、iOS 和 Share Extension 的状态描述不一致。

## 3. 目标状态

- 根部入口明确 iOS 为唯一主开发平台，Web 为冻结历史验证原型。
- `PLAN.md` 维护当前 iOS 功能、分支和验收待办。
- 产品范围、v2 规格、导入规格和 ADR 对 Share Extension / Provider Adapter 的状态一致。
- 历史 ExecPlan 保留原始结论，并通过索引与当前状态分离。

## 4. 进度记录

- [x] 检查分支、工作区、代码目录、测试和现有文档。
- [x] 创建 `docs-ios-alignment` 分支。
- [x] 更新根部 README、AGENTS、PLAN、CONTEXT。
- [x] 新增开发状态与分支进度文档。
- [x] 同步产品范围、v2 规格、导入规格和 Share Extension ADR。
- [x] 增加 `.codex/plans/` 历史索引。
- [x] 运行文档检查、iOS 构建和测试。
- [x] 审查 diff 并创建文档 commit。

## 5. 验证计划

- `git diff --check`：文档无尾随空白。
- Markdown 链接与仓库路径检查：新增入口可解析。
- iOS `xcodebuild build` 和 `xcodebuild test`：当前代码基线不因文档变更回归。
- `git diff --stat` 和 staged diff：只包含文档，不包含 `xcuserdata`。

## 6. 结果复盘

- 已更新根部 README、AGENTS、PLAN、CONTEXT，并新增开发状态与分支矩阵。
- 已同步 MVP 范围、Decision Readiness 规格、导入规格、Share Extension ADR 和设计草图索引。
- 已新增 `.codex/plans/README.md`，将历史执行记录与当前状态看板分离。
- `git diff --check` 通过；12 个 Markdown 文件的本地链接检查通过。
- iPhone 16e Simulator 构建通过；XCTest 50 项、XCUITest 6 项全部通过。
- 原有 Xcode `xcuserdata` 仍保持未提交，未进入本次 commit。
- 未验证：真实 iPhone 系统分享面板、相册交互、中文输入和在线平台页面兼容性。
