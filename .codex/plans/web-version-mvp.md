# Rental Comparison 手机 Web MVP

## 1. 任务目标

在仓库 `web_version/` 中交付一个可直接交互的手机 Web 原型，供中国大陆城市长租用户完成一次真实的选房任务。用户可以创建任务、录入至少 2 套租赁方案、补充费用/通勤/条件/看房证据、横向比较、缩小候选范围、确认唯一最终房源、撤回后重新比较，并导出不含原始图片的决策结果。

视觉以用户明确选定的两张 Apple Store 风格设计稿为唯一真值：候选页使用大标题、横向房源卡片和渐进披露；比较页使用对齐的房源头部、分段主题和逐项纵向比较。不得混入此前小宇宙方向。

## 2. 当前状态

- 当前分支为 `codex/product-foundation`，`HEAD` 为 `aa2a8c2`，开始执行前工作区干净。
- 仓库只有产品文档和空工程骨架，没有可运行的 Web 代码。
- MVP 范围以 `docs/product/mvp_scope.md` 为权威，行为以 `docs/specs/spec_001_core_flow.md` 为权威。
- 本地存储 ADR 尚未决策；工程命令、浏览器支持和 OCR 方案尚未落地。
- 视觉真值文件位于用户提供的临时/生成图片路径，执行时复制到 `docs/design/references/` 保留。
- Product Design 持久上下文为空，本任务只使用当前仓库文档和选定图片。

## 3. 目标状态

- `web_version/` 是 React + TypeScript + Vite 的静态客户端工程，使用 npm 管理依赖。
- 工程基于 Product Design `mobile-app` 模板，保留其设备、触控、键盘、安全区和预览运行时。
- 房源字段、截图、看房照片、反馈草稿和测试摘要只保存到当前浏览器 IndexedDB。
- OCR 在浏览器内执行，识别结果为待确认建议；失败时保留截图并允许手动录入。
- P0-1 至 P0-9 均有可观察、可操作的原型路径。
- iPhone 内容视口遵循选定稿的层级、留白、横向浏览与渐进比较；没有综合总分、赢家或系统推荐暗示。
- Chromium 和 WebKit 自动化通过，浏览器中完成实际核心旅程和设计 QA。

## 4. 范围边界

### 本次包括

- 单个进行中或已完成的选房任务。
- 租赁方案手动录入、截图绑定、本地 OCR 建议与确认。
- 结构化费用、首期现金压力、月均居住成本和未知项。
- 条件重要度、单套条件结果、自定义条件。
- 2～5 套比较、基准房源、重点考虑、淘汰与恢复。
- 异常优先看房清单、文本备注和少量本地照片。
- 唯一最终房源、风险确认、选择理由、撤回和本地变化记录。
- 决策报告、本地测试摘要和隐私受控的反馈草稿导出。
- 本地持久化、浏览器兼容、自动化测试和设计 QA。

### 本次不包括

- 账户、云同步、业务服务器、远程生成式 AI、地图路线 API。
- 多人协作、支付、订阅、租后功能。
- 香港、台湾及海外模板的真实验证。
- 正式 Web 产品、Android/iPad 原生应用、Xcode 或 TestFlight。
- 自动行为埋点或后台上传房源数据。

## 5. 影响文件

- `web_version/`：新增完整 Web 原型、资源、测试、构建与 QA 文件。
- `docs/design/references/`：保存两张选定视觉真值。
- `docs/design/web_prototype_map.md`：页面与视觉稿/实现状态映射。
- `docs/adr/0001_local_storage_strategy.md`：确认 IndexedDB 与本地数据策略。
- `README.md`：补充 Web 工程入口和已验证命令。
- `AGENTS.md`：补充已验证技术栈和工程命令。
- `CONTEXT.md`：更新当前阶段和工程事实。
- `.codex/plans/web-version-mvp.md`：记录执行、验证和复盘。

## 6. 执行里程碑

### Milestone 1：初始化与运行时

使用 Product Design `mobile-app` 模板创建 `web_version/`，安装锁定依赖，复制视觉真值和房源照片，启动开发预览。验证 `npm run check:runtime` 和基础构建。

### Milestone 2：领域模型与本地数据

实现任务、租赁方案、费用、条件、看房记录、决策历史和反馈摘要模型；实现 IndexedDB 版本化存储、图片 Blob、示例数据、导入/导出及数据丢失提示。通过领域单元测试。

### Milestone 3：录入和证据

实现任务创建、5 字段渐进式房源录入、截图绑定、本地 OCR 待确认、费用编辑、通勤编辑、条件结果、异常优先看房清单、备注和照片。验证 OCR 失败仍可保存。

### Milestone 4：候选池、比较和决策

按方案 1 实现候选横向卡片；按方案 2 实现成本/通勤/条件/看房证据的渐进比较。实现 2～5 套选择、基准切换、重点考虑、淘汰/恢复、最终确认和撤回。

### Milestone 5：结果、反馈与摘要

实现最终结果页、无原始图片的 HTML 决策报告、匿名本地测试摘要、只含主动输入内容的反馈草稿，以及用户主动附图时的二次确认。

### Milestone 6：验证和文档

运行 runtime check、lint、format check、typecheck、unit test、Sites test、build 和 Chromium/WebKit E2E。捕获候选页和比较页同视口截图，与视觉真值组合比较，修复所有 P0/P1/P2，生成 `design-qa.md` 且结果为 `passed`。更新长期文档和本计划复盘。

## 7. 进度记录

- [x] 核对当前 Git 状态、仓库规则和权威产品文档
- [x] 确认两张视觉真值并排除小宇宙方向
- [x] 选择技术栈与 Product Design 运行时
- [x] 初始化 `web_version/` 并安装依赖
- [x] 实现领域模型、计算和 IndexedDB
- [x] 实现任务/房源/OCR/费用/通勤/条件/看房录入
- [x] 实现候选池、比较、淘汰/恢复和最终决策
- [x] 实现报告、反馈和本地测试摘要
- [x] 完成自动化测试和浏览器验证
- [x] 完成设计 QA、文档更新和最终审计

## 8. 新发现与意外情况

- Playwright 首次缺少匹配版本的浏览器运行时；Chrome 下载因 TLS 中断，改用本机 Chrome channel，WebKit 运行时从备用源安装成功。
- 原型输入后浏览器会把内部设备容器原生滚动到焦点，导致下一页面偏移并露出已关闭键盘；在键盘关闭、标签切换和 Sheet 变化时复位设备容器滚动。
- 比较页百分比列宽会被大图最小内容撑开；改为手机固定列宽并限制溢出。
- 候选页卡内操作导致渐进披露落到首屏外；将主操作移至轮播下方，并保持淘汰为卡片角落的次要动作。
- OCR 中文语言数据首次运行需要下载，但用户房源截图始终在浏览器本地处理；真实中文截图测试在 Chrome 中于 11 秒内完成或进入明确手动降级状态。

## 9. 决策记录

### Decision：React + TypeScript + Vite + npm

选择：使用 Product Design `mobile-app` 模板内置的 React、TypeScript、Vite 和 npm。

原因：满足复杂交互、类型约束、静态构建、iPhone 视口和桌面调试需要；模板提供受保护的触控/键盘运行时。

备选方案：原生 HTML/JavaScript、默认响应式 Web 模板、Next.js。

影响：原型仍是纯静态客户端；不引入服务端运行时。

### Decision：IndexedDB 保存结构化数据与图片

选择：使用浏览器原生 IndexedDB，状态和图片分库存储，不使用 localStorage 保存隐私数据。

原因：支持结构化对象和 Blob，容量更适合截图/照片，符合无业务服务器约束。

备选方案：localStorage、Dexie、SQLite/WASM。

影响：需要版本升级、容量错误和浏览器清理数据提示；真实设备数据不可跨设备恢复。

### Decision：OCR 使用 Tesseract.js 浏览器工作线程

选择：OCR 只在用户主动选择图片后在浏览器执行，建议必须确认才写入字段。

原因：不上传房源截图，符合 Web 原型的本地 OCR 约束；失败可无损降级。

备选方案：不做 OCR、远程 OCR、生成式 AI。

影响：首次加载语言数据较慢；需要明确进度、失败提示和手动路径。

### Decision：方案 1 + 方案 2 分工

选择：候选与详情沿用方案 1；横向比较沿用方案 2。

原因：两张稿分别解决浏览和比较的信息密度问题，且已由用户明确选定。

备选方案：单一矩阵、差异优先列表、小宇宙混合风格。

影响：比较按主题逐步查看，不在单屏堆满所有字段。

## 10. 验证计划

- `npm run check:runtime`：受保护移动运行时未被修改。
- `npm run lint`：应用代码和测试无静态问题。
- `npm run format:check`：格式一致。
- `npm run typecheck`：TypeScript 无错误。
- `npm run test`：费用公式、未知项、状态不变量、摘要隐私通过。
- `npm run test:sites`：静态 Worker 打包规则通过。
- `npm run build`：生成 `dist/client`、`dist/server` 和 hosting metadata。
- `npm run test:e2e`：Chromium 与 WebKit 均完成创建/录入/比较/决策/撤回路径。
- 浏览器人工：检查候选横向滑动、输入键盘、表单、照片、底部导航、比较主题和最终结果。
- 设计 QA：393 × 852 CSS px 内容视口，与两张真值图归一化后组合比较。

## 11. 风险与回滚

- OCR 语言数据体积和首次加载延迟可能影响体验；手动录入始终可用。
- iOS Safari 可能清理 IndexedDB；首次使用和导出附近持续提示。
- 自动化 WebKit 不能完全代替真实 iPhone Safari；实机为上线测试前的未验证项。
- 图片可能占用较大空间；限制单图尺寸/数量并捕获配额错误。
- 回滚：本轮所有实现位于新增 `web_version/` 及明确文档改动中，未触碰 Xcode 目录；删除新增目录并还原文档即可回到 `aa2a8c2`。

## 12. 最终结果与复盘

已完成 React + TypeScript + Vite 手机 Web MVP。P0-1 至 P0-9 均有可操作路径；候选和比较页以 393 × 852 内容视口完成参考图对照，`design-qa.md` 结果为 `passed`。

验证结果：移动运行时完整性、Biome lint/format、TypeScript、8 个领域单元测试、Chrome/WebKit 6 个核心 E2E、Chrome 真实中文截图 OCR、静态构建和 Sites worker 测试全部通过。开发预览由当前会话保持运行。

未验证项：真实 iPhone Safari 的图片选择、中文输入、文件导出、长期 IndexedDB 保留和性能；正式静态托管平台未选择，也未部署。
