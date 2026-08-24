# 开发状态与分支进度

## 状态口径

本文档记录代码分支的相对进度，不替代功能规格。当前开发基线是 `codex/listing-import-share-extension`；“已验证”只表示对应分支已有记录的自动化或本地验证，不代表真实设备、在线平台或真实用户验收完成。

## 分支矩阵

| 分支 | 提交 | 相对主线 | 当前状态 | 主要内容 |
| --- | --- | --- | --- | --- |
| `main` | `b79ac84` | 基线 | 已合并主线 | iOS v2 决策系统、视觉系统、App Icon、对比页和基础首页能力 |
| `codex/listing-import-share-extension` | `93233e5` | 领先 11 个提交 | 当前开发基线 | 多入口导入、Vision OCR、Provider Adapter、Share Extension、房源图片管理、首页迭代 |
| `codex/settings-language-currency` | `d672a70` | 与当前基线存在独立差异 | 待合并 | 语言、货币、主题偏好及持久化测试 |
| `codex/app-icon-design` | `8545db5` | 历史独立交付 | 已完成/已合并相关能力 | 默认与暗黑 App Icon、Asset Catalog 和冲突处理记录 |

## 当前基线能力

当前分支已具备：

- iOS v2 决策模型和 v1 迁移兼容；
- “选房 / 对比 / 待确认”主导航；
- Quick Capture、未知项、验证任务和最终确认；
- 直接录入、链接导入、截图 OCR 和可编辑确认草稿；
- 链家、贝壳、Reddit 的首批解析 fixture 与失败降级；
- Share Extension 接收 URL 并通过自定义 URL Scheme 回到主 App；
- 房源媒体画廊、原始截图、主图选择和单图删除；
- 首页对比切换、重点标签和稳定图片布局。

## 验证证据

- 原生 XCTest 覆盖决策引擎、迁移、未知项、验证任务、媒体和导入解析。
- XCUITest 覆盖主导航、快速捕获、三种添加入口、卡片对比和房源图片管理。
- iPhone 16e Simulator 已用于构建、自动化测试和关键画面检查。
- 真机 App 启动曾验证，但逐项手动交互、系统分享面板和相册链路仍未完整验证。
- Provider 真实在线页面受安全拦截、超时或页面变化影响；fixture 验证不等于在线抓取成功。

## 分支使用规则

- 新的 iOS 功能从当前 iOS 基线创建独立分支。
- 文档和状态引用提交号时，必须同时说明分支，避免把未合并能力写成主线能力。
- 合并前先确认工作区没有 Xcode `xcuserdata`、Derived Data 或其他本地生成文件。
- Web 分支和 Web 历史计划仅用于回溯，不作为 iOS v2 当前实现依据。
