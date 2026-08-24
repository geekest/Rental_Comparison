# 房源详情图片管理与主图选择

## 1. 任务目标

修复房源图片导入后不显示、无法选择主图、移除照片无效的问题，并将图片管理从详情页下方的孤立表单字段提升到房源详情顶部。完成后，用户可以在详情页查看全部房源照片与原始导入截图、添加图片、删除指定图片并选择主图；卡片和详情头图同步显示已选主图。

## 2. 当前状态

- `ListingInlineFieldsView` 直接修改旧版 `Listing.photoIDs`，并在删除时先删文件再由旧模型投影回写；v2 `Evidence` 仍可能保留失效媒体引用。
- `DecisionLegacyProjection` 仅在没有 `.photo` 时才回退 `.screenshot`，因此导入的原始截图不能在详情页统一展示。
- `ListingDetailView` 顶部只显示 `ListingImageView`，下方“照片”字段无法管理单张图片或主图。
- `Option` 没有持久的主图选择，卡片只能取投影数组的第一项。

## 3. 目标状态

- `Option` 保存可选的主图 `Evidence` ID，旧工作区缺失该字段时保持兼容。
- AppStore 提供针对房源媒体证据的添加、删除、设主图与读取操作；删除同时移除关联引用，且不会误删仍被其他证据引用的本地文件。
- 房源详情顶部提供主图画廊、添加照片入口和“管理图片”入口。
- 管理图片页以网格展示照片和原始截图，支持单图删除、设为主图，并清楚标注主图和原始截图。
- 房源卡片与详情头图都使用同一主图；未选主图的旧数据保持原有证据顺序。

## 4. 范围边界

### 本次包括

- 原生 iOS 房源详情页图片画廊与图片管理 Sheet。
- 从系统照片选择器导入房源图片。
- 主图选择、单图移除和原图证据保留。
- v2 Evidence 与旧版 Listing 投影之间的图片顺序和兼容处理。
- 单元测试、构建、Simulator 验证、中文 commit 与推送。

### 本次不包括

- 云端同步、图片压缩服务、图片标注、任意比例裁切器或视频。
- 删除看房验证任务的现场照片；本次只管理房源本身的媒体。
- 重写图片存储目录或对既有媒体文件做批量迁移。

## 5. 影响文件

- `Rental_Comparison/DecisionModels.swift`：Option 新增兼容的主图 Evidence ID。
- `Rental_Comparison/AppStore.swift`：房源媒体证据读写与删除逻辑。
- `Rental_Comparison/DecisionLegacyProjection.swift`：按主图与证据顺序投影卡片图片。
- `Rental_Comparison/DecisionModelMigration.swift`：旧表单回写时保留主图选择。
- `Rental_Comparison/ListingsView.swift`：详情顶部图片画廊和管理入口。
- `Rental_Comparison/ListingInlineFieldsView.swift`：移除失效的图片表单字段。
- `Rental_Comparison/ListingEditorView.swift`：移除与详情页重复的旧图片编辑路径。
- `Rental_ComparisonTests/`：媒体关联、删除、主图与投影回归测试。
- `docs/specs/spec_003_listing_import.md`、`docs/specs/spec_002_decision_readiness_rebuild.md`：记录图片管理行为与兼容性。

## 6. 执行里程碑

### Milestone 1：建立媒体领域操作

要做：增加主图持久字段和 AppStore 媒体 API，确认只处理不属于验证任务的房源媒体。

验证：添加、设主图、删除后 Evidence、Option 关联和本地文件一致。

完成标准：不再通过旧 `Listing.photoIDs` 直接删文件。

### Milestone 2：重构详情页图片体验

要做：在详情页顶部提供主图画廊、添加和管理入口；管理 Sheet 使用图片网格、明确主图/原图标记和破坏性删除操作。

验证：无图、单图、多图、原始截图和主图切换状态均有可观察 UI。

完成标准：用户不需要滚到表单字段就能管理房源图片。

### Milestone 3：兼容投影与测试

要做：让卡片/详情投影优先主图，旧数据按既有顺序回退；补充单元和 UI 可访问标识。

验证：XCTest、构建、Simulator 截图与 diff 检查。

完成标准：导入图片、主图选择与单图移除可保存且不回归验证任务图片。

### Milestone 4：提交与推送

要做：仅暂存本功能文件，创建中文 commit 并推送当前 feature branch。

验证：本地与 `origin/codex/listing-import-share-extension` 指向同一 commit；既有 `Info.plist` 和 Xcode 用户状态不进入 commit。

完成标准：可审查的远端提交已交付。

## 7. 进度记录

- [x] 调查截图问题、详情页、媒体证据与旧模型投影
- [x] 确定媒体管理信息架构
- [x] 完成领域模型与 AppStore 媒体操作
- [x] 完成详情页画廊和图片管理 UI
- [x] 补充回归测试与规格
- [x] 完成验证
- [ ] 提交并推送

## 8. 新发现与意外情况

- 发现：旧版 `Listing.photoIDs` 是由 v2 Evidence 投影得到的临时视图，不适合作为删除媒体的唯一数据源。
- 影响：直接删除文件后，持久 Evidence 仍可能引用该媒体，造成“移除没有反应”或空白图片。
- 处理方式：媒体写操作全部落在 AppStore 的 v2 `state.evidence` 和 `Option.evidenceIDs` 上。

## 9. 决策记录

### Decision：主图保存为 Option 的 Evidence ID

选择：给 `Option` 增加可选 `primaryEvidenceID`，卡片投影先输出它，再输出其他房源媒体。

原因：用户选择可重启后保留，并避免依赖数组顺序猜测主图。

备选方案：把第一张 `.photo` 当主图；实现较小，但无法表达用户选择，也会隐藏截图。

影响：旧 Codable 工作区可因 optional 字段自动兼容；旧数据没有主图时按既有顺序回退。

### Decision：详情顶部使用画廊，管理操作进入 Sheet

选择：顶部保留可见的图片画廊和添加入口，网格、设主图、删除等多项操作收拢到本地 item-driven Sheet。

原因：主图对房源识别很重要，必须在详情首屏可见；批量管理需要比表单行更清楚的图片上下文。

备选方案：把所有操作继续放在 Form Section；图片数量增加后难以确认对象，且不符合用户期待。

影响：图片管理更可发现；删除使用破坏性动作并附带确认。

## 10. 验证计划

- `xcodebuild ... test -only-testing:Rental_ComparisonTests`：媒体与投影单元测试。
- `xcodebuild ... build`：原生 App 编译。
- iPhone 16e Simulator：详情页无图/多图/主图状态截图，检查添加与管理入口。
- `git diff --check`：无空白错误。
- 提交后核对 `git status --short --branch` 和本地/远端 commit SHA。

## 11. 风险与回滚

- 删除操作可能误删被复用的媒体 ID；实施时仅当没有其他 Evidence 引用时删除文件。
- 旧表单更新可能重建 Option；合并逻辑需保留当前的主图选择。
- 真实系统照片选择器和真机长期文件保留仍需另行验证。
- 新功能可通过单个 commit 回滚，既有媒体文件不进行批量删除或迁移。

## 12. 最终结果与复盘

- 已实现：详情页首屏画廊与导航栏“管理图片”入口；管理 Sheet 支持添加、单图设主图、移除并确认。
- 已实现：导入截图和房源照片统一作为房源媒体展示；验证任务图片不会进入房源图片管理。
- 已实现：主图使用 `Option.primaryEvidenceID` 持久保存，旧数据回退到既有证据顺序。
- 已验证：iPhone 16e 构建成功；媒体添加/设主图/删除定向单测通过；全量单元测试通过；详情图片管理与计划看房 UI 测试通过；完整 UI 套件 6/6 通过。首次全量 UI 回归暴露旧测试假定字段首屏可见，已将该用例改为按目标控件滚动验证后重跑通过。
