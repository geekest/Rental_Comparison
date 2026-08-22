# 房源多入口导入

## 1. 任务目标

当前用户主要通过房源详情页手动维护字段后保存，添加成本较高。本任务希望在房源首页右上角加号下提供三种入口：直接录入、链接导入、截图识别；同时支持从其他 App 分享房源链接后进入本 App，解析可识别字段和图片，形成可编辑、可确认的候选房源。

成功后的外部表现：用户可以选择导入方式；直接录入保持现有行为；链接或截图导入后先看到解析结果和来源证据，确认或修改后再保存为候选房源；解析失败时仍可继续手动录入。

## 2. 当前状态

- 原生入口在 `Rental_Comparison/ListingsView.swift`，右上角加号当前直接打开 `QuickCaptureView`。
- `QuickCaptureView` 已支持名称、可选月租和本地照片/截图保存，并通过 `AppStore.captureOption` 写入 v2 `Option / Fact / Evidence`。
- `ListingEditorView.swift` 已支持完整字段编辑和 `PhotosPicker`，适合作为导入结果的确认/修正页面基础。
- `AppStore.swift` 已有本地 JSON 状态和媒体文件落盘；`DecisionModels.swift` 的 `Fact` 支持 `sourceType`、`sourceRef`、`verificationState` 和 `evidenceIDs`。
- 原生 iOS 尚未实现 OCR；现有 Web 原型的 OCR 不能直接作为正式 iOS 实现，且 Web 版本不再同步 v2 功能。
- 产品与 v2 规格当前明确：本地优先、不使用远程生成式 AI；Share Extension 与 URL 解析目前是非目标。
- 当前工作区为 detached HEAD，开始业务代码修改前需再次确认工作区状态和目标分支。

## 3. 目标状态

### 用户行为

1. 房源页右上角加号打开二级选择：`直接录入`、`链接导入`、`截图识别`。
2. `直接录入` 保留当前快速捕获流程，并可进入完整信息编辑。
3. `链接导入` 支持粘贴或接收分享链接，显示解析状态、可识别字段、来源链接和页面图片；结果进入可编辑确认页。
4. `截图识别` 支持选择相册图片，使用本地 OCR 提取可识别字段；图片作为截图 Evidence 保存，结果必须由用户确认后成为已确认 Fact。
5. 链接或 OCR 失败、网络不可用、平台页面变化时，不丢失原始链接/图片，并降级到手动录入。
6. 导入结果不能静默覆盖用户已经确认的字段；字段来源和确认状态可追溯。

### 验收标准

- 加号二级菜单可访问，三个入口均有独立可自动化测试的标识。
- 直接录入的现有保存、媒体保存和候选生成行为不回归。
- 截图 OCR 至少能把测试夹中的名称、租金、地址等可识别文本映射为待确认字段；无法识别的字段保持未知。
- 链接导入支持明确的 Provider Adapter 接口和至少一组稳定的示例 URL；不支持的域名明确提示，不伪造结果。
- 导入图片和来源链接均能在本地持久化，刷新/重启后仍可读取。
- 解析结果确认前不会参与成本计算或决策比较；确认后才写入相应 Fact。
- 通过 XCTest/XCUITest、构建和静态检查；真实 iPhone 的分享面板、相册、中文输入和平台页面兼容性单独记录。

## 4. 范围边界

### 本次包括

- 房源页加号二级入口和三种导入流程。
- 本地 OCR 解析器及字段映射、待确认状态和降级体验。
- 链接导入的解析接口、域名白名单/适配器机制、来源证据和失败状态。
- iOS 系统分享链接进入本 App 的接收链路；具体采用 Share Extension 还是 App URL 入口需先确认。
- 导入图片、来源链接和字段来源的本地持久化及测试。

### 本次不包括

- 对任意网站或所有平台页面作稳定解析承诺。
- 远程生成式 AI、业务服务器、账户、云同步或跨设备恢复。
- 自动登录链家、自如、贝壳、Reddit、Zillow 等平台。
- 自动替用户确认事实、自动评分、自动推荐或自动换汇。
- 在未确认解析结果前直接创建可比较的已确认字段。

## 5. 影响文件

- `Rental_Comparison/ListingsView.swift`：加号二级入口。
- `Rental_Comparison/QuickCaptureView.swift`、`ListingEditorView.swift`：复用直接录入与导入结果确认页面。
- `Rental_Comparison/AppStore.swift`：接收确认后的导入结果并写入 Option、Fact、Evidence。
- `Rental_Comparison/DecisionModels.swift`：必要时补充导入来源、解析状态或来源证据模型。
- 新增 `Rental_Comparison/ListingImport*.swift`：链接适配器、OCR 字段解析和导入草稿，具体文件名待方案确认。
- `Rental_Comparison.xcodeproj/project.pbxproj` / XcodeGen 配置：若采用 Share Extension，需要新增 target、配置和资源。
- `Rental_ComparisonTests/`、`Rental_ComparisonUITests/`：解析器、确认写入、入口和降级场景测试。
- `docs/specs/`、`docs/product/mvp_scope.md`、必要时 `docs/adr/`：在实现前更新产品范围、行为规格和不可逆平台决策。

## 6. 执行里程碑

### Milestone 1：确认平台和解析边界

要做：确认正式目标为原生 iOS；确认是否本轮就交付 Share Extension；确认首批实际支持的链接平台和字段清单。

验证：每个平台都有可测试 URL 样本、允许解析的字段、失败降级规则和隐私边界。

完成标准：产品规格与 ADR 不再把本功能列为非目标，或明确本轮只交付其中一阶段。

### Milestone 2：入口与导入草稿

要做：加入二级入口；建立统一导入草稿模型，承载字段建议、图片、来源 URL、解析状态和错误信息；保持直接录入路径不变。

验证：XCUITest 能从房源页进入三个入口并取消/返回；单元测试验证草稿不覆盖已确认字段。

### Milestone 3：截图识别

要做：使用 iOS 本地 Vision OCR；实现中文/英文文本清理与租金、地址、房源名称等字段的保守映射；导入结果显示待确认字段和原图。

验证：固定测试图片集跑字段映射测试；OCR 失败仍能保存原图并进入手动填写；无网络也可完成。

### Milestone 4：链接导入与分享接收

要做：实现 Provider Adapter 协议和受支持域名适配器；接入粘贴/分享 URL；抓取或读取允许的页面元数据和图片，统一转成导入草稿。

验证：每个适配器用 fixture 测试成功、字段缺失、页面变化、不支持域名和网络失败；真实分享入口单独在 iPhone 验收。

### Milestone 5：确认写入与回归

要做：将确认后的草稿写入 v2 Option、Fact、Evidence，保留 sourceRef 和图片；补充迁移/持久化与 UI 回归。

验证：完整 XCTest/XCUITest、构建、`git diff --check`，并分别记录 Simulator、真机、网络和真实平台页面证据。

## 7. 进度记录

- [x] 阅读仓库规则、产品规格、当前看板和上下文
- [x] 定位原生房源入口、快速捕获、编辑页、状态模型和持久化链路
- [x] 确认当前存在 Share Extension / URL 解析的产品边界冲突
- [x] 确认平台形态：原生 iOS；本轮交付系统 Share Extension
- [x] 确认首批 Provider：链家、贝壳、Reddit；先以真实公开内容链接建立 fixture
- [x] 确认首批字段清单并固化到规格
- [x] 更新产品规格/ADR
- [x] 实现入口与导入草稿
- [x] 实现截图识别
- [x] 实现链接导入与分享接收
- [x] 实现确认写入、测试和验证
- [x] 完成复盘

## 8. 新发现与意外情况

- 发现：现有 v2 模型已经具备来源和证据的基础字段，但没有专门的导入草稿和解析状态。
  - 影响：可以复用本地存储与决策模型，但不能把解析结果直接写入最终 Fact。
  - 处理方式：新增短生命周期导入草稿，确认后再调用 AppStore 写入。
- 发现：Share Extension、URL 解析和原生 OCR 当前均属于规格非目标，但用户已确认将其纳入本轮原生 iOS 实现。
  - 影响：需要先更新规格/ADR，且 Share Extension 会增加工程 target、权限和真机验证工作。
  - 处理方式：先更新 `docs/product/mvp_scope.md`、`docs/specs/spec_002_decision_readiness_rebuild.md` 和必要的 ADR，再实现工程 target。
- 发现：当前工作树为 detached HEAD。
  - 影响：不适合直接开始业务代码提交。
  - 处理方式：实现前由用户指定或切换到工作分支；本计划阶段不创建 branch、不提交。
- 发现：首轮在线检索得到的三个详情链接中，链家详情页触发安全拦截，贝壳详情页超时，Reddit 详情页抓取工具返回内部错误。
  - 影响：不能把在线抓取成功作为本轮自动化测试前提。
  - 处理方式：保留真实链接用于域名/Share Extension 验收，同时使用页面可见文本建立本地 fixture，并将真实网络失败记录为降级场景。
- 发现：用户明确本轮不要求真机验证。
  - 影响：无法在物理设备的系统分享面板中验证扩展展示、签名和各平台 App 的真实分享载荷，但不阻塞本轮完成。
  - 处理方式：以 Share Extension target 构建、URL 路由单测、平台 fixture、Simulator UI 回归作为本轮验收证据；真机分享面板列为后续验收项。

## 9. 决策记录

### Decision：解析结果必须先进入可确认草稿

选择：OCR/链接解析只产生建议，用户确认后才写入已确认 Fact。

原因：符合本项目“证据不自动等于事实”的长期不变量，避免平台页面或 OCR 错误污染成本和比较结果。

备选方案：直接覆盖 Listing/Option 字段；会丢失来源和确认边界，不采用。

### Decision：链接解析采用受支持 Provider Adapter

选择：先定义适配器协议和明确支持列表，不承诺任意 URL。

原因：不同平台页面结构、登录态、反爬和授权约束差异很大；明确失败比伪造字段更安全。

备选方案：通用网页抓取或远程 AI；会引入服务器、隐私、维护和合规风险，不作为当前默认方案。

### Decision：首批平台与接收方式

选择：本轮原生 iOS 交付 Share Extension，首批 Provider 为链家、贝壳、Reddit。

原因：符合用户确认的优先级；Share Extension 能承接系统分享面板中的 URL，Provider Adapter 让平台差异和失败行为可测试、可回滚。

备选方案：仅支持 App 内粘贴 URL；无法满足“从其他 App 分享后进入本 App”的本轮目标。

## 10. 验证计划

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'generic/platform=iOS Simulator' build-for-testing`：通过，包含主 App、Share Extension、单元测试和 UI 测试 target。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,id=558CEBDE-3F8F-404A-987A-961A36D8A83E' test -only-testing:Rental_ComparisonTests`：通过，44 个测试、0 失败。
- 同上 Simulator 目标执行 `testQuickCaptureAllowsNameWithoutRent` 与 `testAddListingMenuShowsThreeImportMethods`：通过，2 个 UI 测试、0 失败。
- `git diff --check`
- 解析器 XCTest：三个首批平台识别、中文/英文字段映射、HTML 元数据/图片候选、Share URL 路由和确认写入均覆盖。
- XCUITest：房源页加号 → 三入口，以及直接录入回归已验证。
- 真机系统分享面板、平台 App 实际分享、相册授权和中文输入：按用户要求本轮不执行。

## 12. 完成复盘

- 已完成：原生 iOS 加号二级入口、链接导入草稿与确认页、截图 OCR 入口、链家/贝壳/Reddit 域名白名单与解析 fixture、Share Extension 接收 URL 并通过自定义 URL Scheme 回到 App、来源链接/图片/确认 Fact 的本地保存。
- 已验证：XcodeGen 工程生成、Simulator build-for-testing、44 个 XCTest、2 个关键 XCUITest、`git diff --check`。
- 未验证：物理设备系统分享面板中的扩展显示与真实分享载荷；三个平台的在线详情抓取受安全拦截/超时/工具错误影响，仅作为手动降级风险记录，不作为成功抓取承诺。

## 11. 风险与回滚

- 平台页面结构变化可能导致适配器失效；通过 fixture、明确失败状态和手动入口回滚到不启用该适配器。
- Share Extension target 和权限配置会增加工程复杂度；若本轮不交付，可先保留粘贴 URL 入口，不修改 target。
- OCR 误识别会污染用户数据；通过待确认状态、来源证据和不覆盖已确认 Fact 控制风险。
- 导入图片会增加本地存储占用；沿用现有媒体清理策略，并在导入失败时避免留下孤儿文件。
- 任何数据模型变更必须保持旧 `state-v2.json` 可读取；必要时增加版本化迁移和回退测试。
