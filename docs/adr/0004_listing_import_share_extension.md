# ADR-0004：房源链接导入与系统 Share Extension

## 状态

已采用；真实系统分享面板与在线平台兼容性待验收

## 背景

用户需要从链家、贝壳和 Reddit 等其他 App 快速保存候选房源。当前产品没有业务服务器，且房源事实必须区分来源和确认状态。

## 决策

1. 原生 iOS 使用 Share Extension 接收网页 URL，并通过 `rentalcomparison://import?url=...` 打开主 App。
2. 主 App 使用受支持 Provider Adapter 解析链家、贝壳和 Reddit，不承诺任意 URL。
3. URLSession 仅在用户主动导入时请求页面；网络结果先进入导入草稿。
4. OCR 使用本地 Vision；解析结果只有在用户确认后才写入 `userConfirmed` Fact。
5. 原始 URL、页面摘要和本地媒体作为 Evidence 保存。

## 影响

- 新增 Share Extension target 和自定义 URL scheme。
- 平台页面变化、反爬、登录墙和网络失败都可能导致链接导入降级为手动录入。
- Share Extension 的真实系统分享面板和代码签名需要后续真机验收；本轮按用户要求不将其作为完成条件，Simulator 仅验证工程编译、URL 路由和 App 内接收链路。
