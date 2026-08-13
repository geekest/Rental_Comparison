# 解决添加房源 PR 与 main 的冲突

## 1. 任务目标

将 PR #8 `codex/add-listing-flow` 更新到已合并 PR #7 的最新 `main`，解决 Git 冲突，并以本次添加房源的功能为优先，同时保留 PR #7 中不重叠的房源展示能力。

## 2. 当前状态

- `origin/main` 位于 `4f4a958`，包含 PR #7 的房源展示改动。
- PR #8 位于 `09d4ffd`，GitHub 状态为 `DIRTY`。
- 两个分支共同修改 `Prototype.tsx`、`domain.ts`、`domain.test.ts`、`prototype.css`、`report.ts`、`core-flow.spec.ts` 和核心规格文档。
- PR #8 的分支目前不再被检出；其原 worktree 处于干净的 detached HEAD，可安全切回该分支。

## 3. 目标状态

- PR #8 合并最新 `main` 后无冲突并可推送。
- 添加房源的定位、结构化 OCR、自由货币、押金/周期费用、看房清单功能保留。
- PR #7 的多图、楼层、通勤方式与展示能力保留，且与新增模型字段一致。
- 相关检查和测试通过。

## 4. 范围边界

### 本次包括

- 在 PR #8 分支中合并 `origin/main`、解决代码/测试/文档冲突、验证并推送。

### 本次不包括

- 合并 PR、修改 `main`、新增功能或清理无关历史 worktree。

## 5. 影响文件

- 以 Git 合并冲突实际报告的文件为准，重点检查 Web 模型、页面、样式、报告、测试和规格文件。

## 6. 执行里程碑

### Milestone 1：建立安全合并上下文

在原 PR #8 worktree 检出分支，确认干净状态并合并最新 `origin/main`。

验证：仅 PR #8 worktree 进入合并状态，主仓库保持 `main` 不变。

### Milestone 2：按产品优先级解决冲突

保留本次聊天的添加房源功能，同时将 PR #7 已实现的展示字段和 UI 接入同一模型。

验证：无冲突标记，类型检查通过。

### Milestone 3：回归验证与交付

运行单测、核心 E2E、静态检查、构建和 Sites 测试，提交合并结果并推送 PR #8。

验证：PR #8 不再显示冲突。

## 7. 进度记录

- [x] 确认 main、PR #7、PR #8 与冲突状态
- [x] 合并最新 main
- [x] 解决冲突并检查产品语义
- [x] 完成验证
- [x] 提交并推送合并结果
- [x] 完成复盘

## 8. 新发现与意外情况

- PR #7 已于 `4f4a958` 合并进 main；无需处理其原始分支或 PR。

## 9. 决策记录

### Decision：冲突解决优先级

选择：添加房源行为和数据完整性优先；同时保留与其不矛盾的房源展示字段与呈现。

原因：这是用户明确指定的本次需求优先级；展示能力依赖同一 Listing 模型，保留可避免回退 main 已合并功能。

## 10. 验证计划

- `npm run check:runtime`
- `npm run typecheck`
- `npm run test:unit`
- `npm run test:e2e`
- `npm run lint`
- `npm run format:check`
- `npm run build && npm run test:sites`

## 11. 风险与回滚

- 合并可能使展示字段或 OCR 字段在同一模型中重复或错配。
- 若验证失败，保留合并现场继续修复；若必须退出，可用 `git merge --abort` 回到 PR #8 合并前提交，不影响 main。

## 12. 结果复盘

- 已将 PR #7 合并后的 main 引入 PR #8。添加房源的定位、地图、OCR、自由货币、费用和看房清单保留；多图、居室数、楼层、通勤方式及其展示和报告能力同步保留。
- 通过运行时完整性检查、类型检查、16 个单元测试、24 个核心端到端用例、lint、格式检查、构建和 Sites 检查。
- 构建仍提示单个客户端 bundle 大于 500 kB；这是既有 Tesseract.js 相关体积提示，本次未引入新依赖。
