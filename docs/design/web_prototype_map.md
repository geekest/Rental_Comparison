# Web 原型页面映射

## 视觉权威

- 候选池：[candidate-gallery.png](references/candidate-gallery.png)
- 渐进比较：[progressive-comparison.png](references/progressive-comparison.png)

两张参考图只定义布局层级和交互框架。房源内容、状态和按钮行为以产品规格为准，不复制 Apple 商品语义，也不引入此前的小宇宙视觉方向。

## 页面与实现

| 页面或状态 | 入口 | 实现位置 | 状态 |
| --- | --- | --- | --- |
| 本地数据说明 | 首次打开 | `web_version/src/Prototype.tsx` | 已实现 |
| 任务设置与新建任务 | 候选池“任务设置” | `TaskEditor` | 已实现 |
| 候选池横向大卡片 | 底部“房源” | `ListingsScreen` | 已实现 |
| 添加租赁方案与本地 OCR | 候选池“添加房源” | `AddListingForm` | 已实现 |
| 费用、通勤、条件、看房编辑 | 房源“查看详情” | `ListingEditor` | 部分实现，字段差距见核心规格 |
| 比较房源管理与基准 | 比较页“调整” | `CompareManager` | 已实现 |
| 成本、通勤、条件、看房比较 | 底部“对比” | `CompareScreen` | 已实现 |
| 条件模板与自定义条件 | 底部“条件” | `ConditionsScreen` | 已实现 |
| 淘汰原因与恢复 | 候选卡片“淘汰”、已淘汰列表“恢复” | `EliminateDecision`、`ListingsScreen` | 已实现 |
| 最终确认与风险复核 | 比较页底部按钮 | `FinalDecision` | 已实现 |
| 结果、导出、撤回 | 确认后 | `ResultSheet` | 已实现 |
| 隐私受控反馈 | 结果页“反馈使用问题” | `FeedbackForm` | 部分实现，图片未打包为附件 |

“部分实现”不改变目标范围；完整差距以[核心流程规格](../specs/spec_001_core_flow.md#当前-web-实现状态)为准。

## 视觉验收证据

- 候选页：`web_version/artifacts/qa/candidate-393x852.png`
- 比较页：`web_version/artifacts/qa/compare-393x852.png`
- 并排对照：`web_version/artifacts/qa/*-reference-vs-implementation.png`
- QA 结论：`web_version/design-qa.md`
