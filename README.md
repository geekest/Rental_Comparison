# Rental Comparison

一款帮助租房者整理候选租赁方案、看清真实成本与风险，并自主完成选房决策的工具。

Rental Comparison 不提供房源供给，也不替用户计算“最佳房源”。它把分散在房源平台、截图、表格和看房记录中的决策证据整理到一次选房任务中，让费用、硬性条件、未知项和判断变化都可见、可追溯。

## 当前阶段

手机 Web 验证 MVP 已在 `web_version/` 实现，当前进入真实用户验证准备阶段：

- 首轮面向中国大陆城市长租用户，通过真实候选房源验证产品价值；
- 已支持录入、比较、重点考虑、淘汰与恢复、最终确认和撤回；
- Web 原型采用 React、TypeScript、Vite、IndexedDB 和浏览器本地 OCR；
- 没有账户、业务服务器、云同步或行为埋点；
- 核心决策闭环已有自动化验证，完整字段和真机差距单独记录，不以“已实现 MVP”掩盖剩余范围；
- Web 验证达到门槛并完成流程修正后，再评估原生 iPhone TestFlight 版本。

## 核心流程

1. 创建一次选房任务，记录城市、单位、基础条件和通勤目标。
2. 用最少字段添加真实租赁方案，其他信息允许稍后补充。
3. 分别整理首期现金压力、月均居住成本、通勤、条件和看房证据。
4. 在 2～5 套候选方案之间横向比较，突出硬性冲突、差异和未知项。
5. 标记重点考虑、淘汰或恢复候选，并保留判断变化记录。
6. 确认唯一最终房源；出现新信息时可以撤回并继续比较。
7. 导出不包含原始截图和看房照片的决策报告。

完整行为和边界以 [核心流程规格](docs/specs/spec_001_core_flow.md) 为准。

## MVP 原则

- **决策优先**：功能直接服务于比较、淘汰或最终选择。
- **透明优先**：明确展示计算依据、信息来源和未知项，不生成综合评分或自动赢家。
- **渐进录入**：首次保存仅要求名称、城市、整租或合租、月租和货币。
- **本地优先**：产品没有业务服务器，房源数据和图片保存在用户当前设备。
- **同口径比较**：整租与合租只比较个人实际支出、通勤、条件和风险等可比信息。
- **可逆决策**：已淘汰方案可以恢复，最终选择也可以撤回。

账户、云同步、多人协作、远程生成式 AI、地图路线自动计算、支付和自动推荐均不在当前 MVP 范围内。完整范围见 [MVP 范围](docs/product/mvp_scope.md)。

## 仓库结构

```text
Rental_Comparison/
├── .codex/plans/                          # 复杂任务执行计划
├── docs/
│   ├── product/                           # 产品目标与 MVP 范围
│   ├── specs/                             # 功能行为与验收标准
│   ├── adr/                               # 架构决策
│   └── design/
│       ├── references/                    # 已确认视觉参考
│       ├── sketch_map.md                  # 设计节点索引
│       └── web_prototype_map.md           # Web 页面与实现映射
├── web_version/                           # 可运行手机 Web MVP
├── Rental_Comparison/                     # 原生 App 占位目录
├── Rental_ComparisonTests/                # 原生单元测试占位目录
├── Rental_ComparisonUITests/              # 原生 UI 测试占位目录
├── AGENTS.md                              # 仓库工程与文档规则
├── CONTEXT.md                             # 业务术语、状态和长期不变量
└── README.md
```

## 文档入口

| 文档 | 用途 | 当前状态 |
| --- | --- | --- |
| [项目上下文](CONTEXT.md) | 业务对象、统一术语、状态与长期不变量 | 已更新至 Web MVP |
| [产品简述](docs/product/product_brief.md) | 用户问题、产品目标、原则与成功指标 | 已确认 |
| [MVP 范围](docs/product/mvp_scope.md) | P0 能力、非目标、验收与验证门槛 | 已确认 |
| [核心流程规格](docs/specs/spec_001_core_flow.md) | 完整流程、数据要求、异常与验收标准 | 已确认 |
| [本地存储策略 ADR](docs/adr/0001_local_storage_strategy.md) | IndexedDB 和本地媒体存储决策 | 已接受 |
| [Web 原型页面映射](docs/design/web_prototype_map.md) | 参考图、页面与实现状态 | 已实现 |
| [Web 工程说明](web_version/README.md) | 运行、验证、数据与 OCR | 已验证 |
| [工程协作规则](AGENTS.md) | 实施、验证、Git 和文档归档约定 | 当前规则 |

文档之间发生冲突时，应先停止实现并确认，不自行选择解释。

## 本地运行

```bash
cd web_version
npm ci
npm run dev
```

本地预览默认打开 `http://127.0.0.1:4173/`。

## 验证与构建

```bash
npm run check:runtime
npm run lint
npm run format:check
npm run typecheck
npm run test:unit
npm run test:e2e
npm run build
npm run test:sites
```

静态产物位于 `web_version/dist/client/`；原型没有服务端运行时依赖，当前没有执行正式部署。

当前代码覆盖范围和下一轮候选缺口见[核心流程规格的实现状态](docs/specs/spec_001_core_flow.md#当前-web-实现状态)。
