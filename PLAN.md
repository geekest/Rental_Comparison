# Rental Comparison iOS 开发看板

## 使用约定

- 当前主开发平台是原生 iOS；`web_version/` 只作为历史验证原型维护。
- “已完成”表示代码与对应自动化验证已存在；Simulator、真机、在线平台和真实用户证据分别记录，不互相替代。
- 历史任务的完整执行过程保存在 `.codex/plans/`，本文件只维护当前状态和下一步。
- 当前看板基于 `codex/listing-import-share-extension`，主线与其他分支差异见 [开发状态与分支进度](docs/development_status.md)。

## 当前基线

- 基线分支：`codex/listing-import-share-extension`
- 基线提交：`93233e5`
- 主线提交：`main` / `b79ac84`
- 当前工作方式：原生 SwiftUI、iOS 17+、本地 Codable JSON 与本地媒体文件；Web 不再同步 v2。

## 已完成

### iOS 决策系统 v2

- [x] Hunt / Option / Fact / Evidence / Unknown / VerificationTask / Criterion / DecisionEvent 领域模型。
- [x] v1 到 v2 的本地迁移、失败回退和旧页面兼容投影。
- [x] “选房 / 对比 / 待确认”导航、Quick Capture 和 Decision Readiness Gate。
- [x] 高影响未知项、验证任务、现场观察、照片证据和最终确认/撤回。
- [x] Universal Core、China Mainland Regional Template、显式货币和跨币种不可静默比较。

### iOS 房源录入与媒体

- [x] 直接录入、链接导入、截图识别三个入口。
- [x] 本地 Vision OCR、可编辑导入草稿、来源与确认状态。
- [x] 链家、贝壳、Reddit 首批 Provider Adapter 和系统 Share Extension。
- [x] 导入失败时保留 URL/原图并降级为手动录入。
- [x] 房源图片画廊、原始截图保留、添加/删除图片和主图选择。

### iOS 首页与设置

- [x] 首页对比加入/取消切换、重点标签可读性和卡片图片布局优化。
- [x] 原生 App Icon 已在主线交付，默认/暗黑资源已接入 Asset Catalog。
- [ ] 设置分支中的语言、货币和主题偏好尚未合并当前基线，见 `codex/settings-language-currency`。

## 进行中

### iOS 真实设备与平台验收

- 状态：代码和 Simulator 自动化已覆盖主要链路；真实设备和在线平台证据仍不完整。
- 需要分别验收：
  - 真机系统 Share Extension 展示与 URL 载荷；
  - 相册授权、截图选择、中文输入和导入确认；
  - 链家、贝壳、Reddit 当前页面的抓取成功与失败降级；
  - 重启后的本地 JSON、媒体和迁移兼容性。

## 待办

- [ ] 完成真实 iPhone 的首轮手动交互验收并记录设备、系统和结果。
- [ ] 为首批 Provider 维护稳定 fixture，并将在线抓取失败与字段缺失纳入回归场景。
- [ ] 决定并实现设置分支的合并顺序，补充语言、货币和主题的真机验证。
- [ ] 评估导入媒体清理、数据备份和迁移失败后的用户恢复入口。
- [ ] 继续补齐 iOS v2 规格中尚未形成完整 UI 的渐进字段、通勤成本和风险证据细节。

## 已知限制

- Share Extension 的工程接入、URL 路由和 App 内接收链路已有验证，但真实系统分享面板尚未完成验收。
- 链家、贝壳和 Reddit 页面可能受反爬、登录墙、超时或页面结构变化影响；不承诺任意 URL 稳定解析。
- Web 自动化不能替代 iOS Simulator 或真实 iPhone 证据。
- 当前工作区的 Xcode `xcuserdata` 是本地环境文件，不属于产品代码，不应提交。

## 历史 Web 状态

- Web MVP 的录入、比较、决策、导出和本地 OCR 曾完成历史验证。
- Web 的完整 runtime 套件仍有已知 Chrome 专用手势失败，且真实 iPhone Safari 未完成验收。
- Web 不再承担 iOS v2 功能实现或正式产品平台责任。
