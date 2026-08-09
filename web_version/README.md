# Rental Comparison Web MVP

手机 Web 验证原型。所有房源、截图、看房照片和反馈草稿保存在当前浏览器 IndexedDB；没有业务服务器或云同步。

## 运行

```bash
npm ci
npm run dev
```

开发预览默认使用 `http://127.0.0.1:4173/`。在 macOS Chrome 中调试，并在 iPhone Safari 中完成真实用户验证。

## 验证

```bash
npm run check:runtime
npm run lint
npm run format:check
npm run typecheck
npm run test:unit
npm run test:e2e
npm run test:runtime
npm run build
npm run test:sites
```

`npm run test:e2e` 在 Playwright Chromium、本机 Chrome 和 Playwright WebKit 中运行核心流程。`npm run test:runtime` 还会运行移动交互、视觉证据和真实截图 OCR 用例。首次运行需要安装相应浏览器运行时。

## 数据与 OCR

- `state` 存入 IndexedDB；图片以 `ArrayBuffer + MIME type` 保存，读取时恢复为 `Blob`，并兼容早期 Blob 记录。
- IndexedDB 写入只在事务完成后报告成功；失败时界面提示用户先导出结果或重新选择图片。
- OCR 由 Tesseract.js 在浏览器本地执行；图片不会上传。
- 识别结果只是待确认建议，只有用户主动采用并保存后才进入比较。
- OCR 失败时截图仍保留，用户可以继续手动填写 5 个必要字段。
- 导出的决策报告与测试摘要不包含原始截图或看房照片。

## 静态构建

`npm run build` 生成 `dist/client/` 和模板要求的静态托管文件。当前未配置生产域名或自动部署。

## 当前实现边界

核心录入、比较、看房、决策、导出和本地反馈流程已经可交互。尚未实现的渐进字段、通勤月支出、比较分组和反馈图片附件见[核心流程规格](../docs/specs/spec_001_core_flow.md#当前-web-实现状态)。真实 iPhone Safari 仍需要真机验收，Playwright WebKit 不能替代该结论。

截至 2026-08-09，runtime 完整性、typecheck、lint、12 项单元测试、15 项核心 E2E、3 个浏览器的真实截图 OCR、构建和 4 项 Sites 测试通过。完整 `test:runtime` 中仍有 2 个 Chrome 专用移动运行时手势用例失败；对应受保护运行时文件未改变，Chromium 与 WebKit 用例通过。下一轮若涉及移动运行时，应先独立复现并处理这两项，不能把完整套件描述为全绿。
