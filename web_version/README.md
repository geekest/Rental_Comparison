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
npm run build
npm run test:sites
```

`npm run test:e2e` 使用本机 Chrome 和 Playwright WebKit。首次运行需要安装相应浏览器运行时。

## 数据与 OCR

- `state` 和图片 `Blob` 均存入 IndexedDB。
- OCR 由 Tesseract.js 在浏览器本地执行；图片不会上传。
- 识别结果只是待确认建议，只有用户主动采用并保存后才进入比较。
- OCR 失败时截图仍保留，用户可以继续手动填写 5 个必要字段。
- 导出的决策报告与测试摘要不包含原始截图或看房照片。

## 静态构建

`npm run build` 生成 `dist/client/` 和模板要求的静态托管文件。当前未配置生产域名或自动部署。
