# 房源多入口导入规格

## 目标

房源页右上角加号提供“直接录入”“链接导入”“截图识别”三个入口，减少用户从其他房源平台整理候选的手工成本。

## 范围

- 正式目标：原生 iOS 17+。
- 本轮接入系统 Share Extension，接收来自其他 App 的网页链接并打开主 App 的链接导入页。
- 首批 Provider：链家、贝壳、Reddit。
- 链接导入使用本地 URLSession 和 Provider Adapter；页面失败、不支持或字段缺失时必须进入手动降级。
- 截图识别使用本地 Vision OCR，不调用远程生成式 AI。

## 用户流程

1. 用户在房源页点击右上角加号。
2. 系统展示三个入口。
3. 直接录入沿用快速捕获流程。
4. 链接导入支持 App 内粘贴链接，也支持系统分享面板传入链接；解析后展示候选字段、原始链接、页面摘要和已下载图片。
5. 截图识别支持从相册选择最多 8 张图片；OCR 结果展示为可编辑建议，原始截图保留为 Screenshot Evidence。
6. 用户在确认页修改或确认后，才保存为候选 Option 和已确认 Fact。

## 首批字段

可识别并填充：房源名称、城市、租赁方式、月租、户型/居室数、面积、地址（页面文本明确出现时）。无法可靠识别的字段保持未知，不使用默认值伪造。

## 来源与确认

- 链接字段使用 `FactSourceType.listing`，保存 `sourceRef`。
- 截图字段使用 `FactSourceType.screenshot`，保存本地媒体 Evidence。
- 解析阶段不写入最终状态；确认页保存后使用 `userConfirmed`。
- 来源网页摘要、来源 URL 和图片作为 Evidence 保存，便于回溯。

## 首轮测试链接

以下链接用于首轮域名识别、Share Extension 接收和 fixture 解析。平台页面会变化，真实页面抓取结果不作为永久测试数据。

| 平台 | 测试链接 | 首轮观察 |
| --- | --- | --- |
| 链家 | `https://m.lianjia.com/chuzu/sh/zufang/SH2106397257317220352.html` | 详情链接可被识别；自动抓取可能触发平台安全拦截 |
| 贝壳 | `https://bj.zu.ke.com/zufang/BJ1907477165083983872.html` | 详情链接可被识别；自动抓取需记录超时或页面变化 |
| Reddit | `https://www.reddit.com/r/MadisonClassifieds/comments/1rjwwqk/apartment_for_rent_live_resortstyle_at_22_slate/` | 公开帖子链接可被识别；字段依赖页面标题和正文可见文本 |

## 失败降级

- 不支持域名：提示当前只支持首批三个平台。
- 网络、反爬、登录或超时：保留用户输入的 URL，允许手动录入。
- OCR 无结果：保留原图，允许手动录入。
- 部分字段缺失：只展示成功提取的字段，其他字段保持待补充。
