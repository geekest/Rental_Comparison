# ADR-0003：Decision Model v2 本地迁移

## 状态

已接受，2026-08-19。

## 背景

原生 iOS v1 使用 `state-v1.json`，并以 `RentalTask` 和包含全部租房字段的 `Listing` 保存数据。v2 需要区分事实、证据、未知项和验证行动；继续扩展 `Listing` 会使地区字段、确认语义、未知处理和迁移边界不断耦合。

## 决定

使用 schema version 2，并以 `state-v2.json` 保存一个 `Hunt` 及其 `Option`、Fact、Evidence、Unknown、VerificationTask、Criterion 与 DecisionEvent。媒体继续保存于既有 `Media/` 目录，v2 只引用媒体 ID。

启动时按以下顺序读取：优先读取可解码的 v2；仅在没有 v2 时读取 v1 并在内存中迁移；v2 原子写入成功后保留 v1 原文件作为恢复来源。v2 读取或写入失败时不得删除 v1，App 继续使用可读状态并显示可恢复错误。

迁移遵循：

- `RentalTask → Hunt`；`Listing → Option`；`ConditionDefinition → Criterion`；`CostItem → Fact`；`InspectionItem → VerificationTask + Evidence`。
- 旧手工字段均为 `user_confirmed`，不得伪造为 `observed`。
- 旧 `photoIDs` 原样保留；旧 inspection note 与照片形成 Evidence 引用。
- 缺失值保持缺失，不写入金额 `0`。
- 迁移函数为纯函数、幂等并由 XCTest 覆盖。

## 备选方案

1. 继续扩展 `Listing`：实现成本低，但无法稳健表达来源、验证状态与地区模板。
2. 直接覆盖 `state-v1.json`：文件更少，但迁移失败可能不可恢复。
3. SwiftData：对当前单个聚合与本地文件需求引入更高迁移复杂度。

## 影响

- 不引入第三方依赖、服务器或云同步。
- v1 和 v2 仅在迁移期间并存；确认 v2 稳定前不得删除 v1。
- 未来多 Hunt 查询、同步或媒体索引需求出现时，需重新评估存储框架并新增 ADR。

## 验证

- v1 fixture 迁移保留名称、费用、条件、照片、看房状态和决策事件。
- 未知费用不转为 `0`，`unchecked / okay / issue` 正确映射。
- 连续运行迁移保持结果等价。
- 模拟 v2 写入失败后，v1 文件仍可读取。
