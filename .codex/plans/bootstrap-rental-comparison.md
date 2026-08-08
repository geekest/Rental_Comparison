# 建立 Rental_Comparison 工程结构

## 1. 任务目标

当前目录为空，尚未形成可供后续产品设计与 App 开发使用的统一工程骨架。

本任务将按用户指定的目录树建立 `Rental_Comparison` 项目结构，将示例名称 `YourApp` 统一替换为 `Rental_Comparison`，并为项目说明、产品文档、规格、ADR 和设计索引提供最小可维护的 Markdown 初始内容。

成功的外部表现是：在 `/Users/geekest/Rental_Comparison` 下可以看到指定的文档结构，以及 `Rental_Comparison/`、`Rental_ComparisonTests/`、`Rental_ComparisonUITests/` 三个 App 相关目录。

## 2. 当前状态

- 当前目录：`/Users/geekest/Rental_Comparison`
- 执行前当前目录为空；现已创建本 ExecPlan、目标文档与目录骨架。
- 已按用户追加要求初始化 Git 仓库，当前分支为 `bootstrap-project`，尚无提交。
- 当前没有 `README.md`、工程配置、源码、测试或构建脚本。
- 当前没有仓库级 `AGENTS.md`；用户已明确要求创建。
- 已读取 `/Users/geekest/.codex/repo_agents_demo.md`，后续 `AGENTS.md` 将以该模板为基础，并对无法确认的技术事实标注“待确认”。
- 现阶段没有可运行的测试、lint、typecheck 或 build 命令。

## 3. 目标状态

- 根目录包含 `AGENTS.md`、`CONTEXT.md` 和 `README.md`。
- `docs/` 下包含用户指定的 product、specs、adr、design 四类文档。
- `YourApp/` 替换为 `Rental_Comparison/`。
- `YourAppTests/` 替换为 `Rental_ComparisonTests/`。
- `YourAppUITests/` 替换为 `Rental_ComparisonUITests/`。
- Git 仓库初始化在非主分支 `bootstrap-project`，三个暂时为空的 App 目录通过 `.gitkeep` 纳入版本控制。
- Markdown 文件包含简洁、可继续填写的结构；未知产品事实一律标记为“待确认”，不虚构需求或技术方案。
- 目录与文件命名和用户给出的结构一致，不引入额外架构。

验收标准：

- 使用 `find` 检查目录树，所有指定路径均存在。
- 使用 `rg` 检查项目文件，除说明替换关系的 ExecPlan 外，不残留 `YourApp` 占位命名。
- 检查所有 Markdown 标题和内部链接，确保项目名统一为 `Rental_Comparison`。

## 4. 范围边界

### 本次包括

- 创建用户列出的目录与 Markdown 文件。
- 将所有 App 目录命名替换为 `Rental_Comparison` 对应名称。
- 为文档写入最小、清晰且不虚构业务事实的初始模板。
- 创建符合全局模板要求的仓库级 `AGENTS.md`。

### 本次不包括

- 初始化 Git 仓库，并直接使用非主分支 `bootstrap-project`。
- 为三个空目录添加 `.gitkeep`，使目录骨架可被 Git 跟踪。
- 不生成 `.xcodeproj`、`Package.swift`、Swift 源文件或测试代码。
- 不安装依赖，不选择具体 UI、数据持久化或架构框架。
- 不补写尚未提供的产品需求、用户故事或视觉设计。
- 不提交、推送或创建 PR。

## 5. 影响文件

- `AGENTS.md`：记录当前可确认的项目级工程事实与待确认项。
- `CONTEXT.md`：提供项目上下文入口和文档导航。
- `README.md`：说明项目名称、当前状态和目录结构。
- `docs/product/product_brief.md`：产品简述模板。
- `docs/product/mvp_scope.md`：MVP 范围模板。
- `docs/specs/spec_001_core_flow.md`：核心流程规格模板。
- `docs/adr/0001_local_storage_strategy.md`：本地存储策略 ADR 模板，状态保持为待决策。
- `docs/design/sketch_map.md`：设计草图索引模板。
- `Rental_Comparison/`：App 主目录，目前为空。
- `Rental_ComparisonTests/`：单元测试目录，目前为空。
- `Rental_ComparisonUITests/`：UI 测试目录，目前为空。
- `Rental_Comparison/.gitkeep`：让空的 App 主目录可以被 Git 跟踪。
- `Rental_ComparisonTests/.gitkeep`：让空的单元测试目录可以被 Git 跟踪。
- `Rental_ComparisonUITests/.gitkeep`：让空的 UI 测试目录可以被 Git 跟踪。
- `.codex/plans/bootstrap-rental-comparison.md`：本任务 ExecPlan，执行过程中持续更新。

## 6. 执行里程碑

### Milestone 1：确认现状与规则

要做：

- 检查工作目录、Git 状态和已有文件。
- 阅读全局 `PLANS.md` 与仓库级 `AGENTS.md` 模板。
- 明确命名替换和范围边界。

为什么做：

- 避免覆盖已有文件或虚构项目约定。

验证：

- 能明确说明执行前目录为空、不是 Git 仓库、没有现有规则文件。

完成标准：

- “当前状态”和“范围边界”已记录已确认事实。

### Milestone 2：创建工程与文档骨架

要做：

- 创建根目录文档、`docs/` 子目录及其文档。
- 创建 `Rental_Comparison/`、`Rental_ComparisonTests/`、`Rental_ComparisonUITests/`。
- 写入最小文档模板，并统一项目名称。

为什么做：

- 为后续需求沉淀、技术决策和 App 开发建立清晰入口。

验证：

- 使用 `find` 对照目标目录树。
- 使用 `rg` 检查名称一致性。

完成标准：

- 所有指定路径存在，文档内容不包含未经确认的业务事实。

### Milestone 3：验收与复盘

要做：

- 检查全部新增文件内容。
- 检查命名、Markdown 格式、重复内容和范围外文件。
- 更新 ExecPlan 的进度、发现、决策和最终复盘。

为什么做：

- 确保交付结构准确、整洁、可继续维护。

验证：

- 目录树和文件内容检查均通过。

完成标准：

- 最终回复可以列出改动、验证结果、未验证项和风险。

## 7. 进度记录

- [x] 检查当前目录和 Git 状态
- [x] 阅读全局 ExecPlan 规范
- [x] 阅读仓库级 `AGENTS.md` 模板
- [x] 明确任务范围与命名规则
- [x] 用户确认 ExecPlan，并追加 Git 初始化要求
- [x] 初始化 Git 仓库与 `bootstrap-project` 分支
- [x] 创建工程目录与文档骨架
- [x] 检查项目命名一致性
- [x] 执行目录树和 Markdown 验收
- [x] 完成结果复盘

## 8. 新发现与意外情况

- 发现：当前路径不是 Git 仓库。
- 影响：无法按 Git 分支与 diff 流程审查，也无法让 Git 跟踪空目录。
- 处理方式：用户已明确要求初始化 Git；使用非主分支并通过文件系统与 Git 状态共同验收。

- 发现：用户给出的结构没有 `.xcodeproj` 或 Swift 源文件。
- 影响：无法据此确认最低系统版本、SwiftUI/UIKit、测试框架或构建命令。
- 处理方式：本次只建立指定骨架，相关事实统一标记为“待确认”。

- 发现：用户确认执行时追加要求初始化 Git。
- 影响：空目录默认无法被 Git 跟踪，且全局规则禁止直接在主分支修改。
- 处理方式：使用 `git init -b bootstrap-project` 初始化非主分支，并为三个空目录增加 `.gitkeep`。

- 发现：当前环境未安装 `markdownlint` 或 `markdownlint-cli2`。
- 影响：无法运行专用 Markdown lint。
- 处理方式：使用尾随空白扫描、内部链接检查和逐文件自检替代，并在最终结果中说明。

## 9. 决策记录

### Decision：严格按指定树创建最小骨架

选择：仅创建指定目录和 Markdown 文件，App 相关目录除用于 Git 跟踪的 `.gitkeep` 外保持为空。

原因：用户当前要求是建立工程结构，且给出的目标树未包含 Xcode 工程文件或源码。

备选方案：直接创建完整 Xcode 工程；该方案会引入平台版本、Bundle Identifier、UI 框架等未经确认的决策，因此不采用。

影响：完成后具备文档与目录骨架，但还不能直接编译运行。

### Decision：未知内容使用“待确认”

选择：文档提供最小章节结构，所有未知业务和技术事实标记为“待确认”。

原因：避免把模板内容误当成已经确认的产品或架构决策。

备选方案：根据项目名推测租房对比需求；该方案存在静默扩展范围和错误沉淀风险，因此不采用。

影响：后续需要结合正式需求继续完善文档。

### Decision：使用非主分支并跟踪空目录

选择：初始化分支为 `bootstrap-project`，并在三个 App 相关空目录中添加 `.gitkeep`。

原因：满足用户初始化 Git 的追加要求，同时遵守不直接操作主分支的规则，并让目标目录结构进入版本控制。

备选方案：初始化默认分支并保留真正的空目录；前者可能落在主分支，后者无法通过 Git 复现目录结构，因此不采用。

影响：目标树会比用户示意图多三个隐藏占位文件；后续加入真实源码或测试文件后可删除对应 `.gitkeep`。

## 10. 验证计划

- `find . -maxdepth 4 -print | sort`：目标目录和文件全部存在，无范围外工程文件。
- `git branch --show-current`：预期输出 `bootstrap-project`。
- `git status --short --branch`：预期显示尚无提交，且仅包含本任务新增内容。
- `rg -n "YourApp" --glob '!bootstrap-rental-comparison.md' .`：预期无匹配。
- `rg -n "Rental_Comparison" AGENTS.md CONTEXT.md README.md docs`：预期核心入口文档使用统一项目名。
- 逐文件检查 Markdown：标题层级清晰，不虚构命令、依赖、业务需求或技术结论。
- 构建、测试、lint、typecheck：本阶段没有工程配置或源码，无法运行；最终明确说明。

## 11. 风险与回滚

- 兼容性风险：低。当前目录为空，不存在旧行为。
- 数据风险：低。不修改现有用户文件。
- 架构风险：低。不做技术选型，不生成可执行工程。
- 空目录风险：已通过 `.gitkeep` 解决；后续加入真实源码或测试文件后可删除占位文件。
- 回滚方式：当前尚无提交，可逐项删除本次明确新增的文件与目录；本任务不会自动执行回滚或删除操作。

## 12. 最终结果与复盘

### 实际完成

- 初始化 Git 仓库，当前分支为 `bootstrap-project`，未创建提交。
- 创建根目录的 `AGENTS.md`、`CONTEXT.md` 和 `README.md`。
- 创建产品、MVP、核心流程、ADR 和设计索引文档模板。
- 创建 `Rental_Comparison/`、`Rental_ComparisonTests/`、`Rental_ComparisonUITests/`，并通过 `.gitkeep` 纳入 Git。
- 所有未知产品和技术内容均保留为“待确认”。

### 与原计划的差异

- 用户确认执行时追加了 Git 初始化要求，因此新增 Git 仓库、`bootstrap-project` 分支和三个 `.gitkeep` 文件。
- 未生成 `.xcodeproj`、Swift 源码或依赖，范围边界保持不变。

### 修改文件

- `.codex/plans/bootstrap-rental-comparison.md`
- `AGENTS.md`
- `CONTEXT.md`
- `README.md`
- `docs/product/product_brief.md`
- `docs/product/mvp_scope.md`
- `docs/specs/spec_001_core_flow.md`
- `docs/adr/0001_local_storage_strategy.md`
- `docs/design/sketch_map.md`
- `Rental_Comparison/.gitkeep`
- `Rental_ComparisonTests/.gitkeep`
- `Rental_ComparisonUITests/.gitkeep`

### 验证结果

- 目标路径存在性检查通过。
- 目录树检查通过。
- 项目文件中的 `YourApp` 残留检查通过，无匹配。
- `Rental_Comparison` 命名检查通过。
- Markdown 内部链接检查通过。
- Markdown 尾随空白检查通过。
- Git 分支检查通过，当前为 `bootstrap-project`。

### 未验证内容

- 没有可执行工程、源码或测试，因此无法运行 build、单元测试、UI 测试、lint 或 typecheck。
- 当前环境没有可用的 Markdown lint 命令。

### 风险与后续

- 当前骨架不能直接编译运行；下一阶段需要确认目标平台、工程生成方式和产品范围。
- 加入真实源码或测试文件后，可以删除对应目录中的 `.gitkeep`。
- 本次已创建仓库级 `AGENTS.md`，暂不需要额外沉淀新的仓库规则。
