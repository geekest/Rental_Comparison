# Design QA

## 目标与证据

- 参考 1：`../docs/design/references/candidate-gallery.png`
- 参考 2：`../docs/design/references/progressive-comparison.png`
- 候选页实现：`artifacts/qa/candidate-393x852.png`
- 比较页实现：`artifacts/qa/compare-393x852.png`
- 候选并排：`artifacts/qa/candidate-reference-vs-implementation.png`
- 比较并排：`artifacts/qa/compare-reference-vs-implementation.png`
- 目标内容视口：393 × 852 CSS px

## QA 历史

1. 首轮候选页的卡片和固定导航均存在，但卡内操作导致首屏无法看到渐进披露；将操作移到轮播外，并缩短卡片密度。
2. 首轮比较页的百分比卡宽被图片最小内容撑开；改为固定手机列宽并限制溢出。
3. iOS 文本输入后设备容器保留原生焦点滚动，导致比较页和键盘错位；在关闭键盘、切换标签和关闭 Sheet 时复位设备容器滚动。
4. 最终候选页保留大标题、横向大卡、下一张露出、页点、卡外操作与披露；比较页保留两列对齐、分段主题、大数字指标、差异提示和无综合分声明。

## 严重度检查

- P0：0。核心内容均可见，主流程无阻断。
- P1：0。固定导航、横向卡片、比较列宽和键盘状态均已修复。
- P2：0。选定两张参考图的层级、留白、圆角、主次按钮和渐进披露已对齐；实际房源照片允许与生成稿不同。

final result: passed
