# 原生 iOS 租房对比 App

## 1. 任务目标

当前仓库已有可运行的手机 Web MVP，但缺少能够在 Xcode 与 iOS Simulator 中直接构建运行的原生版本。本任务以当前 `main` 的 Web 实现和已确认产品规格为基准，使用 SwiftUI 复刻核心选房闭环，并遵循 iOS 的导航、表单、辅助功能和本地数据惯例。

成功的外部表现是：用户能在原生 iOS App 中查看、添加、编辑、淘汰和恢复房源，选择 2～5 套进行长页面比较，管理条件与看房记录，确认或撤回最终房源，并导出不含原始图片的决策报告；工程可在 iOS Simulator 构建、启动并通过自动化测试。

## 2. 当前状态

- Web 实现位于 `web_version/`，核心状态、成本计算、报告生成和界面分别位于 `src/domain.ts`、`src/calculations.ts`、`src/report.ts`、`src/Prototype.tsx`。
- 已确认的行为以 `docs/specs/spec_001_core_flow.md` 为准，主导航为房源、对比、条件。
- 当前 `main` 已包含添加房源、房源展示与长页面对比的合并结果。
- 仓库中尚无原生 App 源码或 Xcode 工程；`Rental_ComparisonTests/` 和 `Rental_ComparisonUITests/` 仅有占位文件。
- Web 使用 IndexedDB；原生端尚未确认持久化框架。本次选择无外部依赖的 Codable 文件存储，相关决定记录到 ADR。
- 本机存在 `/Applications/Xcode.app`，但系统 `xcode-select` 指向 Command Line Tools；本任务通过 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 使用完整 Xcode，不修改全局设置。

## 3. 目标状态

- iOS 17+ SwiftUI App，使用 `TabView`、`NavigationStack`、原生 sheet、`Form`、`ShareLink` 与 SF Symbols。
- `@Observable` 根状态负责跨页面数据；编辑表单使用局部值状态，保存时统一归一化。
- 状态以版本化 JSON 原子写入 Application Support；示例图片随 App 资源提供，用户照片使用 PhotosPicker 数据落盘。
- 对比计算、条件风险、看房异常、候选归一化和报告输出拥有单元测试。
- 关键控件具备可读标签、动态字体适配、非颜色唯一状态提示和自动化标识。
- 在 iPhone Simulator 构建、运行、截图并验证核心导航。

## 4. 范围边界

### 本次包括

- 当前 Web MVP 的候选房源、比较、条件、看房、最终选择和本地导出核心流程。
- 本地状态持久化和示例数据。
- 原生照片选择、系统分享和 iOS 辅助功能语义。
- 原生工程、单元测试、UI 测试、README、规格和存储 ADR 更新。

### 本次不包括

- 账号、云同步、多人协作、支付、订阅、远程生成式 AI、自动地图路线和综合评分。
- Web 端浏览器定位、OpenStreetMap 与 Tesseract OCR 的原生等价实现；原生端保留手动录入与照片绑定。
- Android、iPad 专门布局、App Store 签名与 TestFlight 发布。
- 与 Web IndexedDB 的自动迁移或跨端导入。

## 5. 影响文件

- `project.yml`：声明可复现的 Xcode 工程结构和 targets。
- `Rental_Comparison/`：SwiftUI App、模型、存储、业务计算、报告与界面。
- `Rental_ComparisonTests/`：核心业务单元测试。
- `Rental_ComparisonUITests/`：启动与主导航 UI 测试。
- `docs/adr/0002_native_ios_local_storage.md`：记录原生本地存储取舍。
- `docs/specs/spec_001_core_flow.md`：补充原生实现状态和已知边界。
- `README.md`：补充原生工程生成、构建、运行和测试方法。

## 6. 执行里程碑

### Milestone 1：确认基准与搭建工程

要做：盘点 Web 数据模型、交互、视觉参考和验收项；创建 XcodeGen 配置、App 入口、资源与最小 SwiftUI 壳。

验证：生成 `.xcodeproj` 后首次构建无编译错误。

完成标准：模拟器可启动包含 3 个主标签的空壳 App。

### Milestone 2：移植领域逻辑与持久化

要做：实现 Codable 模型、示例状态、归一化、成本计算、报告生成、JSON 文件存储与照片存储。

验证：单元测试覆盖成本、候选归一化、硬条件、报告隐私和持久化往返。

完成标准：核心逻辑不依赖 UI，修改后自动持久化。

### Milestone 3：实现核心原生流程

要做：实现房源卡片与详情、添加/编辑、条件与看房、比较长页、选择管理、最终确认/撤回和导出。

验证：编译通过；关键状态拥有 Preview 或 fixture；核心控件有 accessibility identifier。

完成标准：从候选到最终选择的主流程可在 Simulator 完成。

### Milestone 4：视觉与运行时验收

要做：在模拟器检查布局、动态字体语义、空状态、错误状态与主要交互；修复视觉和运行时问题。

验证：运行单元测试、UI 测试、Debug 构建；截图检查候选、对比和条件页面。

完成标准：构建、测试、启动和核心导航均有成功证据。

### Milestone 5：文档与复盘

要做：更新 README、规格、ADR、计划结果，检查 diff 与风险。

验证：`git diff --check`、自审差异、确认未引入生产依赖与敏感信息。

完成标准：交付文件、验证结果与未验证项完整可审查。

## 7. 进度记录

- [x] 阅读仓库规则、产品规格和现有 Web 实现
- [x] 确认视觉目标与 iOS 组件映射
- [x] 创建隔离 Worktree 与任务分支
- [x] 完成原生工程与 App 壳
- [x] 完成领域逻辑、持久化与测试
- [x] 完成房源、对比、条件和最终选择流程
- [x] 完成模拟器运行与 UI 验收
- [x] 更新长期文档和最终复盘

## 8. 新发现与意外情况

- 发现：`main` 已通过 PR #7、#8、#9 包含此前并行分支的房源展示、添加流程与长页面对比能力。
- 影响：无需从未合并分支拼装需求，直接以 `main` 为唯一实现基准。
- 处理方式：在 `main` 派生 `codex/ios-native-app`。
- 发现：系统开发目录未指向完整 Xcode。
- 影响：直接调用 `xcodebuild` 会失败。
- 处理方式：所有构建命令显式设置 `DEVELOPER_DIR`，不修改用户全局开发目录。
- 发现：iOS 26.3 Simulator 第一次启动需要约 7 分钟完成 Data Migration 和 System App 初始化。
- 影响：最初的测试任务长时间等待，容易被误判为测试死锁。
- 处理方式：等待 `simctl bootstatus -b` 明确返回 Finished 后再运行 XCTest；随后单元和 UI 测试均正常通过。
- 发现：初版 XcodeGen 配置将可执行产品名设为含空格的 `Rental Comparison`，自动生成的测试宿主路径使用 `Rental_Comparison`。
- 影响：首次 `test` 找不到测试宿主。
- 处理方式：产品可执行名统一为 `Rental_Comparison`，面向用户的显示名继续由 `CFBundleDisplayName` 使用“租房对比”。

## 9. 决策记录

### Decision：使用 SwiftUI 与 iOS 17 Observation

选择：最低目标 iOS 17，使用 `@Observable` 根状态与原生 SwiftUI 导航/表单。

原因：符合当前 SwiftUI 数据流，减少样板代码，且本项目是新的原生实现，不需兼容遗留 UIKit。

备选方案：支持 iOS 16 并使用 `ObservableObject`；会增加状态样板且无已知业务需求。

影响：iOS 16 设备不在本次支持范围。

### Decision：版本化 Codable JSON 本地存储

选择：业务状态写入 Application Support 的版本化 JSON，媒体单独落盘。

原因：当前只有一个聚合任务，结构小且本地优先；此方案可测试、易导出、无需迁移框架或生产依赖。

备选方案：SwiftData；对单聚合状态引入模型拆分和迁移复杂度，收益不足。

影响：未来需要多任务查询或复杂检索时应重新评估 SwiftData，并提供迁移路径。

### Decision：原生语义优先于逐像素复刻 Web 容器

选择：保留信息层级、文案、主色和关键卡片结构，但使用系统 Tab、导航栏、sheet、Form、按钮和分享界面。

原因：用户要求同时参照 iOS 与 Swift 标准规范；复制 Web 的模拟状态栏、悬浮底栏和自制键盘会违背平台惯例。

备选方案：像素级复制 Web 外壳；视觉接近但可访问性、键盘和系统行为较差。

影响：原生截图不会与 Web 逐像素相同，但核心视觉语言与任务路径保持一致。

## 10. 验证计划

- `xcodegen generate`：成功生成工程。
- `xcodebuild`：Debug 构建并在可用 iPhone Simulator 启动。
- `xcodebuild test`：单元测试与 UI 测试通过。
- 模拟器 UI 快照：候选、对比、条件、添加房源、详情和最终确认关键页面可达。
- `git diff --check`：无空白错误。
- 自审：无无关重构、外部依赖、密钥、绝对个人路径或图片数据进入导出报告。

## 11. 风险与回滚

- 兼容性：最低 iOS 17；回滚可删除原生目录与工程生成配置，不影响 `web_version/`。
- 数据：原生和 Web 各自本地存储，不自动互通；持久化失败时保留当前会话并展示错误。
- 性能：示例数据量小；图片以文件保存并缩略显示，避免写入 JSON。
- 功能差距：OCR、地图和 Web 数据迁移不在本次范围，会在规格和交付中明确。
- 签名：模拟器无需个人签名；真机和 TestFlight 仍需用户开发者团队配置。

## 12. 最终结果与复盘

### 实际完成

- 新建 iOS 17+ SwiftUI App 与可直接打开的 Xcode 工程，未引入第三方生产依赖。
- 完成候选房源卡片、添加与编辑、本地照片、结构化费用、通勤、重点考虑、淘汰与恢复。
- 完成 2～5 套房源长页面比较、基准切换、成本/通勤/条件/看房分组和最终选择。
- 完成条件维护、逐套结果、看房检查、结果页、撤回和隐私型 HTML 报告分享。
- 完成版本化 JSON 原子持久化、媒体独立落盘、示例数据与保存错误提示。
- 更新 README、核心规格、仓库构建命令和原生存储 ADR。

### 与计划差异

- XcodeBuildMCP 因系统 `xcode-select` 指向 Command Line Tools 而无法调用 `simctl`；改为给本任务的 `xcodebuild` 与 `xcrun` 命令显式设置 `DEVELOPER_DIR`，未修改全局配置。
- 原计划使用 XcodeBuildMCP 截图，实际使用 `simctl io screenshot` 完成候选、对比和条件页面视觉验收。

### 验证结果

- `xcodegen generate`：成功。
- iPhone 16e / iOS 26.3 Simulator Debug build：成功。
- `Rental_ComparisonTests`：7 项全部通过。
- `Rental_ComparisonUITests`：2 项全部通过，覆盖添加表单和三个主标签。
- 最终全量 `xcodebuild test`：9 项全部通过。
- 模拟器安装、启动：成功；候选、对比、条件三页已截图检查。
- `git diff --check`：通过；新增 Swift、YAML 与 Markdown 文件另经尾随空白扫描通过。

### 未验证

- 未在真实 iPhone 上验证照片选择、中文输入、长期存储和分享。
- 未配置个人开发者 Team、真机签名或 TestFlight。
- 未实现 Web IndexedDB 到原生 JSON 的迁移、OCR 或地图选点。

### 后续与规则沉淀

- 原生构建/测试命令已加入仓库 `AGENTS.md`，无需再增加全局规则。
- 下一步应在真实 iPhone 上完成一轮核心流程验收，再决定 TestFlight 配置与 Web 数据迁移优先级。
