# PR8 与 PR9 合并兼容

## 1. 任务目标

确保先合并 PR8「完善添加房源流程」后，PR9「房源对比改为长页面」能无冲突并保留两项需求：PR8 的扩展房源数据与录入流程，以及 PR9 的连续比较和模块定位。

## 2. 当前状态

- PR8 曾与 `main` 冲突，但分支现已新增合并提交 `623c929`，并以当前 `main` 为父级。
- PR8 与 PR9 都修改 `web_version/src/Prototype.tsx`、`web_version/src/prototype.css`、`web_version/tests/core-flow.spec.ts` 与视觉 QA 图片。
- PR8 已将 PR7 的居室数、楼层、通勤方式与多图展示，同位置、OCR、费用、看房清单录入整合。
- PR9 仍基于 PR7 前的基线，其连续比较与快速定位尚未叠加 PR8 的数据模型。

## 3. 目标状态

- PR9 包含 PR8 已修复的父级，用户按 PR8 → PR9 的顺序合并时不会出现 Git 冲突。
- 长页面保留成本、通勤、条件、看房四组内容与快速定位，并使用 PR8 的货币、通勤方式和新看房清单数据。
- 合并结果保持既有录入、OCR、费用计算、房源展示和比较主流程可用。

## 4. 范围边界

### 本次包括

- 将 PR8 已修复分支合并至 PR9，逐段解决共有文件冲突。
- 修正 PR9 比较页对 PR8 新字段的展示兼容，并更新测试与视觉 QA。

### 本次不包括

- 新增产品能力、依赖、数据迁移或受保护移动运行时改动。
- 合并 PR、修改 `main` 或强制推送。

## 5. 影响文件

- `web_version/src/Prototype.tsx`：PR8 录入/展示与 PR9 比较共用的页面组件。
- `web_version/src/prototype.css`：候选、录入及比较布局均有改动。
- `web_version/tests/core-flow.spec.ts`：两项功能的端到端覆盖。
- `web_version/artifacts/qa/*.png`：须从最终叠加状态重生成。

## 6. 执行里程碑

### Milestone 1：建立冲突矩阵

比对 PR8 修复提交和 PR9，确认共有文件、PR8 已解决的需求和 PR9 要保留的比较行为。

验证：可复现 PR8 → PR9 的冲突清单。

### Milestone 2：修复 PR9 的兼容性

将 PR8 合并至 PR9，在共有组件中保留 PR8 逻辑并施加 PR9 的连续比较与定位。

验证：工作树无未解决冲突；比较页支持 PR8 新的数据展示规则。

### Milestone 3：验证和交付

运行类型、lint、单元、核心 E2E、构建和静态站点检查；检查 PR9 相对 PR8 后基线可合并。

验证：PR8、PR9 均可合并，且用户指定顺序可行。

## 7. 进度记录

- [x] 读取规则、PR 元数据与当前工作树
- [x] 建立冲突矩阵
- [x] 修复 PR9 的兼容性
- [x] 运行合并与自动化验证
- [x] 完成复盘

## 8. 新发现与意外情况

- 发现：PR8 已有新的合并提交 `623c929`，其父级为 PR8 原始提交与当前 `main`。
- 影响：不应重复解决或覆盖 PR8 已合并的冲突。
- 处理方式：将该提交直接合并到 PR9，再解决剩余的 PR9 语义冲突。

## 9. 决策记录

### Decision：合并 PR8 到 PR9 而非重写历史

选择：创建普通 merge commit，将 PR8 合入 PR9。

原因：避免强制推送，完整保留 PR8 与 PR9 的审核历史；PR8 合入 `main` 后，其祖先提交会自然从 PR9 的差异中排除。

备选方案：PR9 变基到 PR8；会改写已推送历史，需强制推送和额外确认。

影响：PR8 尚未合入 `main` 时，PR9 的 GitHub 比较可能临时包含 PR8 的改动；按用户指定顺序合并 PR8 后，PR9 会仅显示自身差异。

## 10. 验证计划

- Git 合并与 `git diff --check`：确认没有未解决冲突。
- `npm run check:runtime`、`npm run typecheck`、`npm run lint`、`npm run format:check`。
- `npm run test:unit`、`npm run test:e2e`、`npm run build`、`npm run test:sites`。
- GitHub PR 元数据：确认 PR8、PR9 均为可合并。

## 11. 风险与回滚

- 风险：`Prototype.tsx` 是两个 PR 的共享大文件，错误选择冲突版本可能遗失录入或比较能力。
- 处理：以 PR8 版本为数据和录入真相，在其上逐段恢复 PR9 的比较行为，并用测试验证。
- 回滚：不动 `main`；PR9 仅增加可回退 merge commit，必要时可 revert 该 commit。

## 12. 最终结果与复盘

已完成：将 PR8 的合并提交 `623c929` 合入 PR9，并解决了 `Prototype.tsx` 与两张视觉 QA 截图的冲突。比较页保留 PR9 的连续四模块、快速定位、当前模块状态与逐房源对齐；同时保留 PR8 的自由货币、周期费用、通勤方式、房源展示、位置/OCR/费用录入及看房清单。成本差异文案改为使用当前房源货币，混合货币时明确不做直接比较。

实际修改：PR9 合并包含 PR8 已修复分支的内容，并新增本计划文件；视觉 QA 从最终叠加状态重生成。`web_version/src/Prototype.tsx` 的兼容变更包括成本模块锚点和自由货币差异展示。

验证：`npm run check:runtime`、`npm run typecheck`、`npm run lint`、`npm run format:check`、`npm run test:unit`（16 项）、Chromium/Chrome/WebKit 核心 E2E（每个内核 8 项）、Chromium 视觉 QA、`npm run build` 与 `npm run test:sites` 均通过。

未验证：未做真实 iPhone Safari 的手工交互与外部地图/定位服务验收；自动化 WebKit 不能替代真机。

风险：PR8 未合入 `main` 前，PR9 的 GitHub 差异会临时包含 PR8 的提交；用户按 PR8 → PR9 顺序合并后，PR8 将成为 `main` 祖先，PR9 只保留自身的增量差异。本次没有新增需写入 `AGENTS.md` 的长期规则。
