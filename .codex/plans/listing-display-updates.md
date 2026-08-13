# 房源展示页信息补全

## 1. 任务目标

补全房源首页卡片的信息和交互：用户可以记录并看到楼层、整租或合租的居室数、通勤方式；同一房源保存多张照片后，可以只在卡片图片区域横向查看照片，而在卡片其他区域继续横向切换房源卡片。

## 2. 当前状态

- `web_version/src/domain.ts` 的 `Listing` 已记录租赁方式、面积、通勤时长、单次通勤支出及一张本地截图 ID，但没有楼层、居室数、通勤方式和房源照片集合。
- `web_version/src/Prototype.tsx` 的 `ListingsScreen` 使用外层 `Carousel` 横向切换房源卡片；每张卡片只渲染一张图片。`ListingEditor` 可以补充基本信息，`AddListingForm` 可以绑定一张截图。
- 运行时 `Carousel` 已支持嵌套横向手势与父级纵向滚动的轴向分配；尚未用于卡片内图片。
- `docs/specs/spec_001_core_flow.md` 仍将楼层、通勤方式记为未完成项。

## 3. 目标状态

- `Listing` 可以持久化楼层、居室数、通勤方式和额外本地照片 ID，同时可读取没有这些字段的旧本地记录。
- 新增和编辑房源时可填写或修改楼层、居室数和通勤方式，并可保存多张房源照片。
- 候选卡片显示楼层、`整租 X 居` 或 `合租 X 居`，以及通勤方式与时长。
- 两张及以上图片时，卡片图片区使用嵌套 `Carousel` 横滑；卡片外层保留原有横向切换手势。

## 4. 范围边界

### 本次包括

- 房源展示、录入、编辑、本地持久化和相关自动化测试。
- 对现有房源样例和功能规格进行同步。

### 本次不包括

- 远程图片、云同步、图片删除/排序、OCR 识别楼层或通勤方式。
- 比较页新增楼层或户型分组。

## 5. 影响文件

- `web_version/src/domain.ts`：扩展房源字段和样例数据。
- `web_version/src/Prototype.tsx`：录入、编辑、图片展示和卡片信息。
- `web_version/src/prototype.css`：卡片图片轨道和信息布局。
- `web_version/src/domain.test.ts`：覆盖新增字段与旧记录兼容。
- `web_version/tests/core-flow.spec.ts`：覆盖用户可见展示与多图横滑。
- `docs/specs/spec_001_core_flow.md`：更新实现状态。

## 6. 执行里程碑

### Milestone 1：扩展数据与录入路径

要做：添加新字段、样例数据和新增/编辑入口。

验证：单元测试确认新建房源字段和旧记录归一化行为。

完成标准：字段可在当前浏览器的 IndexedDB 状态中保存与恢复。

### Milestone 2：实现卡片展示和嵌套图片手势

要做：将卡片图片区改为多图媒体轨道，展示新增文案。

验证：Playwright 检查文本与图片轨道；运行时检查确保受保护的移动运行时未被改动。

完成标准：图片区域横滑不触发房源详情，卡片外部仍由外层轨道负责横滑。

### Milestone 3：回归验证和复盘

要做：补齐规格状态，运行单测、端到端、静态检查、构建并审查差异。

验证：所有命令通过，或明确记录无法执行项。

完成标准：计划记录实际结果与风险。

## 7. 进度记录

- [x] 阅读相关文件并确认当前数据流和手势契约。
- [x] 创建执行计划。
- [x] 完成数据模型与录入路径。
- [x] 完成卡片展示与图片横滑。
- [x] 补充自动化测试。
- [x] 完成验证与复盘。

## 8. 新发现与意外情况

- 发现：当前工作树中不存在用户提到的根目录 `PLAN.md`，仅有历史 ExecPlan；本计划按仓库约定新建于 `.codex/plans/`。
- 影响：不阻塞本次已明确的需求实现。
- 处理方式：将用户列出的待办作为本计划的权威执行范围。
- 发现：初版图片轨道把百分比宽度项目放进 `max-content` 容器，轨道会收缩为单图宽度。
- 影响：多图卡片无法横滑。
- 处理方式：图片宽度与房源卡片保持一致，在窄屏断点同步缩小，并用 3 个浏览器内核的拖拽测试验证。
- 发现：抽屉关闭时的透明遮罩会在退出动画结束前拦截指针。
- 影响：测试不能立即对底层图片轨道发起拖拽。
- 处理方式：端到端测试等待遮罩卸载；未修改受保护的移动运行时。

## 9. 决策记录

### Decision：复用移动运行时 Carousel

选择：在卡片图片区嵌套现有 `Carousel`。

原因：它已实现横向优先、纵向交还父级和拖动后抑制点击的手势契约，满足图片区与房源卡片区的交互边界。

备选方案：使用原生 `overflow-x` 或自定义指针事件。

影响：不改动受保护的移动运行时，样式只定义图片轨道。

## 10. 验证计划

- `npm run check:runtime`
- `npm run test:unit`
- `npm run test:e2e`
- `npm run typecheck`
- `npm run lint`
- `npm run format:check`
- `npm run build`

## 11. 风险与回滚

- 旧 IndexedDB 状态可能缺少新字段：渲染与归一化将提供默认值或保留未知，不强制迁移数据库版本。
- 多张本地照片会增加本地存储占用：本次沿用既有用户主动选择、仅本地保存的边界。
- 嵌套横滑可能影响父级手势：仅使用运行时 `Carousel`，并以端到端测试与运行时校验覆盖。
- 回滚方式：移除本次字段和 UI 改动即可恢复原始单图行为；本地记录中的额外字段会被旧版本忽略。

## 12. 最终结果与复盘

- 实际完成：`Listing` 增加楼层、居室数、通勤方式和本地照片集合；旧记录缺少照片集合时归一化为空数组。新增房源必须输入居室数，详情可编辑楼层、居室数、通勤方式并补充多张照片。
- 卡片展示：显示 `整租 X 居` 或 `合租 X 居`、楼层、通勤方式与时长。多张照片仅在图片区使用嵌套 `Carousel` 横滑；卡片外部保留原有房源横滑轨道。
- 规格同步：更新 `docs/specs/spec_001_core_flow.md` 的字段和通勤实现状态；报告中的通勤信息也显示方式。
- 修改文件：`web_version/src/domain.ts`、`web_version/src/Prototype.tsx`、`web_version/src/prototype.css`、`web_version/src/report.ts`、`web_version/src/domain.test.ts`、`web_version/tests/core-flow.spec.ts`、`docs/specs/spec_001_core_flow.md`。
- 验证：`npm run format:check`、`npm run check:runtime`、`npm run lint`、`npm run typecheck`、`npm run test:unit`（14 项）、`npm run test:e2e`（21 项，Chromium / Chrome / WebKit）、`npm run build`、`npm run test:sites`（4 项）均通过。
- 未验证：未进行真实 iPhone Safari 的人工触摸验收；构建仍有既有的主 JS 产物超过 500 kB 提示。
- 后续：本次没有新增可复用的仓库级工程规则，无需更新 `AGENTS.md`。
