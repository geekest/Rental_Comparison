# SPEC-002：Decision Readiness iOS 重构

## 文档状态

- 状态：已确认，实施中
- 最近更新：2026-08-24
- 适用阶段：iOS P0
- 替代关系：本规格是 v2 iOS 的权威行为；[SPEC-001](spec_001_core_flow.md) 仅保留 v1 兼容语义。

## 目标

用户不应感觉自己在维护房源数据库。对于一次 Hunt，App 必须帮助用户：捕获候选、追溯关键事实的来源与确认状态、识别高影响未知项、转化为验证任务，并在最终选择前理解取舍、风险与剩余 blocker。

## 领域与状态

| 对象 | 用途 | 关键要求 |
| --- | --- | --- |
| Hunt | 一次选房决策 | 一个 active Hunt；可 active、completed、archived |
| Option | 真实候选方案 | 包含 SearchStage 与 DecisionState，二者不共用状态机 |
| Fact | Option 的结构化事实 | 保存 key、值、来源、确认状态、更新时间和关联 Evidence |
| Evidence | 截图、照片、用户观察或手动记录 | 保存元数据与媒体 ID；不自动认定事实真伪 |
| Criterion | 用户关心的标准 | importance 为 required、preferred、ignored |
| Unknown | 可能影响决策的缺失信息 | 有 impact、reason、状态；未知不等于 0 或冲突 |
| VerificationTask | 解决 Unknown 的行动 | ask、check、observe、photo、measure；可 pending、verified、issue、skipped |
| DecisionEvent | 改变决策上下文的记录 | 不为每个 UI 细节生成事件 |

`SearchStage` 至少支持 `saved`、`viewing_planned`、`viewed`、`unavailable`；`DecisionState` 支持 `candidate`、`eliminated`、`final`，重点考虑为独立 Bool。Fact 的 `VerificationState` 支持 `unknown`、`extracted`、`user_confirmed`、`observed`。

## 主导航与页面

一级导航固定为“选房 / 对比 / 待确认”。“选房重点”移至 Hunt Settings，不再是一级 Tab。

### 选房

- 展示 Hunt 名称、城市、候选数、blocker 数与当前阶段。
- 按以下优先级给出一个 Next Best Action：高影响 blocker、即将看房的任务、已有至少 2 个候选但尚未比较、添加候选、最终确认。
- Option 卡片只呈现图片、名称、月租、通勤、2 至 3 个关键差异、Readiness、blocker 数与 SearchStage；完整字段进入详情。

### 对比

- 至少 2 个候选才可比较，一次最多 5 个。
- 默认顺序为 Hard conflicts、Major differences、Decision blockers、Known trade-offs、Everything else。
- 不展示自动赢家、综合评分或静默货币换算。不同货币须明确标记不可直接比较。
- Full Matrix 是二级入口；基准能力仅在其仍能改善阅读时保留，且不得暗示推荐。

### 待确认

- 展示所有 high-impact Unknown、即将看房 Option、询问与看房任务、已完成验证记录。
- 每个任务可快速标记“无问题 / 有问题 / 跳过”；有问题时才展开备注与照片。

### Option 详情

- 依次呈现决策摘要、Facts、Evidence、Unknown、VerificationTask 和 Full Details。
- 对已知 Fact 显示值、sourceType、verificationState 与更新时间。
- 对关键未知显示原因、影响级别和“添加信息”或“创建验证任务”入口。

## 捕获、未知与验证

### Quick Capture

首次添加只要求名称；月租、货币、截图或照片都允许稍后补充。名称加截图必须可保存为 Option。城市继承 Hunt，完整表单为二级的 Full Details。

### Unknown 规则

仅当缺失信息可能影响决策时生成 Unknown：required Criterion 未满足或未知、费用类关键 Fact 未确认、看房风险未验证、候选间可能改变判断的未知项，或用户主动标记的问题。P0 只使用 high、medium、low，不计算伪精确分数。已确认或现场观察的对应 Fact 必须自动 resolve；同一 Option 与 Fact key 不得重复生成 active Unknown。

### VerificationTask 闭环

Unknown 可生成 ask、check、observe、photo 或 measure 任务。完成任务可添加 note、照片与 Evidence，并可写入 Fact；若解决事实未知则关闭 Unknown，若记录问题则保留为 known risk 并记录 DecisionEvent。

## Decision Readiness 与最终选择

Option Readiness 为 `not_ready`、`needs_verification`、`ready_with_known_risks`、`ready`。有 high-impact Unknown 时必须为 `needs_verification`；没有 blocker 且 required Criterion 已确认时为 `ready`；风险已知且用户接受时为 `ready_with_known_risks`。

Hunt 至少需要 2 个 candidate、至少一个 ready 或 ready_with_known_risks Option，且用户已查看主要 trade-off，才能进入常规最终确认。仍可强制继续，但必须明确确认未解决信息。

最终确认页必须依序展示：选择理由、Known trade-offs、Unresolved blockers、Known risks、Evidence coverage。确认后 Hunt 为 completed；撤回后恢复 active，Option 回到 candidate，DecisionEvent 保留。

## Universal Core、模板、货币与成本

Universal Fact key 包含 monthly_rent、deposit、recurring_fee、one_time_fee、area、area_scope、bedroom_count、available_date、lease_months、commute_minutes、commute_cost、pet_allowed、parking、cooking、elevator、noise、natural_light、internet、furnished。ChinaMainlandTemplate 只负责默认货币、面积单位、候选 Criterion、默认验证项与文案，地区字段不得新增为 Option 顶层属性。

Hunt 保存默认 ISO 4217 货币；界面使用系统 Locale。不同货币禁止直接比较且 P0 不自动换汇。成本保留月均住房成本、首期现金、可退押金不计入月均成本与未知成本不按 0 的规则；每笔费用有金额、货币、cadence、refundable、verificationState 和 Evidence。

## v1 迁移与兼容

- v1 `RentalTask` 映射为 Hunt，`Listing` 映射为 Option，`ConditionDefinition` 映射为 Criterion，`CostItem` 映射为费用 Fact，`InspectionItem` 映射为 VerificationTask 与 Evidence。
- 既有手动录入的值迁移为 `user_confirmed`，不得升级为 `observed`。
- `unchecked / okay / issue` 分别映射为 `pending / verified / issue`；旧 note 与 photoIDs 转为 Evidence。
- Option 可选保存 `primaryEvidenceID` 作为房源卡片与详情头图的主图；旧工作区缺少该字段时按既有 Evidence 顺序回退。
- 迁移必须保留原 v1 文件，先原子写入 v2 成功后再切换。失败时继续读取 v1、报告可恢复错误且不清空数据。迁移重复执行必须幂等。

## 验收

1. A/B/C 场景中，C 的宠物 required conflict、A 的 utilities blocker、B 的夜间噪音验证任务均可见。
2. B 看房后记录噪音 issue，会关闭 Unknown、保留 known risk 和 Evidence；A 确认 utilities 后可达到可决策状态。
3. 最终选择 A 时，页面呈现每月便宜 ¥700、通勤多 20 分钟、无高影响 blocker 的依据；确认后 Hunt completed，撤回后恢复 active。
4. v1 fixture 迁移后照片、决策历史与未知值不丢失；迁移失败不覆盖 v1。
5. `xcodebuild build` 与完整 XCTest/XCUITest 通过；真机验收另记录图片、中文输入、系统 Locale、货币、分享、重启与迁移结果。

## 非目标

房源搜索、供给聚合、自动申请、签约、支付、登录、云同步、综合评分、自动赢家、远程 AI、任意 URL 解析、地图自动通勤、多人协作、Android 和 iPad 专门布局不在本轮 P0。Share Extension、首批 Provider Adapter 和本地 OCR 的具体行为，以 [房源多入口导入规格](spec_003_listing_import.md) 为准；真实系统分享面板和在线平台兼容性不因 Simulator 或 fixture 通过而自动视为完成。
