# Rental Comparison

帮助租房者整理候选房源、确认事实与证据、识别高影响未知项，并自主完成可追溯的选房决策。

## 当前开发阶段

原生 iOS 是当前唯一的主开发目标，`web_version/` 已冻结为历史验证原型，不再同步 iOS v2 功能。

当前开发基线为 `codex/listing-import-share-extension`，已包含：

- Decision Readiness v2：Hunt、Option、Fact、Evidence、Unknown、VerificationTask 和 DecisionEvent；
- v1 到 v2 的本地迁移与旧页面兼容投影；
- “选房 / 对比 / 待确认”主导航、Quick Capture、未知项和验证任务闭环；
- 房源链接导入、截图 OCR、可编辑确认草稿和系统 Share Extension；
- 链家、贝壳、Reddit 首批 Provider Adapter；
- 房源图片管理、原始截图保留和主图选择；
- 首页对比切换、重点标签可读性和现有 iOS 视觉系统优化。

当前已验证的主要范围是 iPhone 16e Simulator 的构建、XCTest/XCUITest 和本地 fixture。真实 iPhone 的系统分享面板、相册交互、中文输入以及在线平台页面兼容性仍需单独验收。

各分支的代码进度见 [开发状态与分支进度](docs/development_status.md)。

## 核心流程

1. 创建一次选房任务，记录城市、地区模板和决策目标。
2. 通过快速捕获、链接导入或截图识别保存候选房源。
3. 在确认事实来源的基础上补充费用、条件、图片和看房证据。
4. 优先处理高影响未知项和验证任务，再比较候选之间的关键差异。
5. 标记重点考虑、淘汰或恢复候选，并保留决策变化记录。
6. 在理解取舍、风险和未解决 blocker 后确认最终房源；新信息出现时可以撤回。

完整行为以 [Decision Readiness iOS 重构规格](docs/specs/spec_002_decision_readiness_rebuild.md) 和 [房源多入口导入规格](docs/specs/spec_003_listing_import.md) 为准。

## 产品边界

- 本地优先：没有业务服务器、账户、云同步或自动埋点。
- 证据优先：OCR 和链接解析只产生可编辑建议，用户确认后才写入已确认 Fact。
- 透明比较：不生成综合评分、自动赢家或静默货币换算。
- 可逆决策：已淘汰候选可恢复，最终选择可撤回。
- 当前不包含房源搜索、自动申请、签约、支付、远程生成式 AI、地图自动通勤、多人协作、Android 和 iPad 专门布局。

## 仓库结构

```text
Rental_Comparison/
├── Rental_Comparison/                     # 原生 SwiftUI App
├── Rental_ComparisonShareExtension/       # iOS 系统分享扩展
├── Rental_ComparisonTests/                # 原生业务单元测试
├── Rental_ComparisonUITests/              # 原生主流程 UI 测试
├── web_version/                           # 已冻结的手机 Web 验证原型
├── docs/product/                          # 产品目标、范围和指标
├── docs/specs/                            # iOS 功能行为与验收标准
├── docs/adr/                              # 存储、迁移和平台决策
├── docs/development_status.md             # 当前分支与验证状态
├── .codex/plans/                          # 历史与当前 ExecPlan
├── AGENTS.md                              # 工程协作规则
├── CONTEXT.md                             # 业务术语和长期不变量
├── PLAN.md                                # 当前开发看板
└── README.md
```

## 文档入口

| 文档 | 用途 |
| --- | --- |
| [开发状态与分支进度](docs/development_status.md) | 当前基线、分支差异和验证证据 |
| [当前开发看板](PLAN.md) | iOS 主线已完成、进行中和待办 |
| [项目上下文](CONTEXT.md) | 领域对象、状态和长期不变量 |
| [Decision Readiness 规格](docs/specs/spec_002_decision_readiness_rebuild.md) | iOS v2 权威行为 |
| [房源多入口导入规格](docs/specs/spec_003_listing_import.md) | 链接、截图和 Share Extension 行为 |
| [MVP 范围](docs/product/mvp_scope.md) | 产品范围和验证门槛 |
| [原生 iOS 本地存储 ADR](docs/adr/0002_native_ios_local_storage.md) | Codable JSON 和本地媒体策略 |
| [Web 工程说明](web_version/README.md) | 历史 Web 原型运行与验证方式 |

## 本地运行与验证

### 原生 iOS

直接用 Xcode 打开 `Rental_Comparison.xcodeproj`，选择 `Rental_Comparison` Scheme 和 iPhone Simulator。

如果修改了 `project.yml`，先运行：

```bash
xcodegen generate
```

构建与测试：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Rental_Comparison.xcodeproj \
  -scheme Rental_Comparison \
  -destination 'platform=iOS Simulator,name=iPhone 16e' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Rental_Comparison.xcodeproj \
  -scheme Rental_Comparison \
  -destination 'platform=iOS Simulator,name=iPhone 16e' test
```

### 历史 Web 原型

```bash
cd web_version
npm ci
npm run dev
```

Web 的测试、构建和已知限制见 [`web_version/README.md`](web_version/README.md)。

文档发生冲突时，优先检查 `CONTEXT.md`、当前适用的 `docs/specs/` 和 [开发状态与分支进度](docs/development_status.md)；不要把历史 Web 验证结果当作当前 iOS 验收结果。
