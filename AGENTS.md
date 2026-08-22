# AGENTS.md

## 项目概览

本仓库用于建设 `Rental_Comparison` App。当前先通过 `web_version/` 验证手机 Web MVP，具体产品目标以 `docs/product/` 下的产品文档为准。

主要技术栈：

- 目标平台：Web 验证原型；正式产品仍以 iPhone 为目标
- 开发语言：TypeScript
- UI 框架：React 19
- 数据存储：IndexedDB
- 测试框架：Vitest、Playwright
- 构建工具：Vite、npm、Biome

## 目录结构

- `Rental_Comparison/`：App 主代码目录
- `Rental_ComparisonTests/`：单元测试目录
- `Rental_ComparisonUITests/`：UI 测试目录
- `docs/product/`：产品目标与 MVP 范围
- `docs/specs/`：功能规格与验收标准
- `docs/adr/`：架构决策记录
- `docs/design/`：设计草图与页面索引
- `.codex/plans/`：复杂任务的 ExecPlan
- `web_version/`：手机 Web 验证原型、测试与静态构建

## 文档权威关系

- `AGENTS.md` 规定工程执行方式和文档归档规则。
- `CONTEXT.md` 记录业务对象、术语、状态和长期不变量。
- `docs/product/product_brief.md` 说明产品目标与用户问题。
- `docs/product/mvp_scope.md` 定义 MVP 范围边界。
- `docs/specs/` 定义具体功能行为和验收标准。
- `docs/adr/` 记录重要技术决策及其原因。
- `docs/design/sketch_map.md` 维护 Sketch 设计节点与实现状态之间的映射。
- 文档发生冲突时，先停止实现并确认，不自行选择解释。

## 文档职责与内容边界

| 文件或目录 | 应保存 | 不应保存 |
| --- | --- | --- |
| `AGENTS.md` | 已验证的构建命令、代码规范、Git 与中文 PR 规则、完成标准、禁止事项、文档归档规则 | 产品需求、页面功能细节、临时任务、单次实现方案 |
| `CONTEXT.md` | 业务对象、统一术语、业务状态及其含义、跨功能长期有效的不变量 | 某个页面的颜色、视觉像素、单次需求细节、临时任务进度 |
| `docs/product/` | 目标用户、用户问题、产品目标、MVP 边界、核心指标 | 详细代码方案、类与函数设计、具体存储实现 |
| `docs/specs/` | 单个功能的完整行为、前置条件、主流程、状态变化、异常与边界、验收标准 | 全项目长期知识、通用工程规范、无关功能需求 |
| `docs/adr/` | 难以逆转或回滚成本高的技术决策及原因，例如选择 SwiftData、最低 iOS 版本、关键架构方案 | 普通需求讨论、未收敛的头脑风暴、临时实现记录 |
| `docs/design/sketch_map.md` | Sketch 文件、Page、Frame、Layer ID、设计状态与实现状态映射 | 重复描述所有视觉像素、产品需求全文、代码实现细节 |

### 归档判断顺序

新增或更新信息时，依次判断：

1. 是否是长期有效的工程执行规则；是则写入 `AGENTS.md`。
2. 是否是跨功能复用的业务知识或长期不变量；是则写入 `CONTEXT.md`。
3. 是否定义用户问题、产品目标、MVP 边界或指标；是则写入 `docs/product/`。
4. 是否描述单个功能的完整可观察行为；是则写入 `docs/specs/`。
5. 是否属于难以逆转的技术取舍；是则写入 `docs/adr/`，并记录背景、备选方案、选择和影响。
6. 是否用于连接 Sketch 设计节点与实现状态；是则写入 `docs/design/sketch_map.md`。
7. 如果只是临时任务、执行步骤或短期进度，不写入上述长期文档；复杂任务记录到 `.codex/plans/`。

同一信息只保留一个权威来源。其他文档需要引用时使用链接，不复制整段内容。

## 安装、启动与构建

- 安装依赖：`cd web_version && npm ci`
- 本地启动：`cd web_version && npm run dev`
- 构建：`cd web_version && npm run build`
- 重新生成 iOS 工程：`xcodegen generate`
- iOS 构建：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,name=iPhone 16e' build`

## 测试与验证

- 单元测试：`cd web_version && npm run test:unit`
- UI 测试：`cd web_version && npm run test:e2e`
- 移动运行时：`cd web_version && npm run check:runtime`
- 静态产物：先运行 `npm run build`，再运行 `npm run test:sites`
- Lint：`cd web_version && npm run lint`
- Typecheck：`cd web_version && npm run typecheck`
- Format：`cd web_version && npm run format:check`
- iOS 测试：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,name=iPhone 16e' test`

新增功能时，应根据影响范围同步补充测试或记录无法验证的原因。

## 代码风格

- App、测试 Target 与目录统一使用 `Rental_Comparison` 命名。
- 优先遵循后续工程中已经形成的代码风格，不做无关重构。
- 具体架构、模块划分和状态管理方案未确认前，不提前创建抽象层。

## Git 与 PR

- 不直接在主分支修改代码。
- 分支名称使用简短英文单词和短横线。
- commit 标题使用中文，说明本次改动的核心结果。
- PR 标题和描述使用中文；描述应包含变更原因、实现方案和验证结果。
- 未经明确要求，不执行 commit、push 或创建 PR。
- 除非用户本人明确要求，禁止 Codex 自行新建 PR。
- 除非用户本人明确要求，禁止 Codex 自行新建 branch。
- 如果用户当前位于 `main`，无法直接提交 commit 时，应说明当前无法在 `main` 上提交，并建议用户切换到其他 branch，不得自行新建 branch。

## 依赖新增规则

- Web 原型已确认 React、移动原型运行时和 Tesseract.js 等锁定依赖，具体版本以 `web_version/package-lock.json` 为准。
- 新增生产依赖前，需要说明用途、替代方案、维护风险和体积影响，并获得确认。

## 高风险变更

- 数据模型、迁移、本地存储策略和兼容方案必须先更新对应 ADR 或规格文档。
- 权限、鉴权、支付、生产配置、密钥和环境变量相关变更必须先确认。
- 不提交密钥、Token、个人路径或本地私有配置。

## 禁止事项

- 不把产品需求、页面规格或临时任务写入 `AGENTS.md`。
- 不把单个页面的视觉细节或一次性需求写入 `CONTEXT.md`。
- 不在产品文档中提前固化代码实现方案。
- 不用 ADR 代替普通需求讨论，也不为可轻易调整的小决定创建 ADR。
- 不在 `sketch_map.md` 中重复描述可直接从 Sketch 查看、且不影响映射关系的所有视觉像素。
- 不编造构建、测试、依赖或平台信息；未知内容标记为“待确认”。

## 完成标准

- 实现结果符合已确认的产品范围和功能规格。
- 相关测试、构建或静态检查已运行；无法运行的项目已明确说明。
- 文档与用户可见行为保持一致。
- 已检查改动范围、边界场景、重复逻辑和潜在回归。
