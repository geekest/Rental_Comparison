# Rental_Comparison

`Rental_Comparison` App 的项目仓库。

## 当前状态

产品方向、Web 验证 MVP 边界和核心流程已经确认，正式实现尚未开始。当前下一阶段应先完成手机 Web 原型的工程决策和真实用户验证，再根据验证闸门决定是否开发原生 iPhone TestFlight 版本。

仓库当前没有可编译运行的工程。技术栈、构建方式、本地持久化和 OCR 方案仍待确认，不记录未经验证的命令。

## 目录结构

```text
Rental_Comparison/
├── .codex/
│   └── plans/
├── AGENTS.md
├── CONTEXT.md
├── README.md
├── docs/
│   ├── product/
│   │   ├── product_brief.md
│   │   └── mvp_scope.md
│   ├── specs/
│   │   └── spec_001_core_flow.md
│   ├── adr/
│   │   └── 0001_local_storage_strategy.md
│   └── design/
│       └── sketch_map.md
├── Rental_Comparison/
├── Rental_ComparisonTests/
└── Rental_ComparisonUITests/
```

三个 App 相关目录暂时使用 `.gitkeep` 纳入 Git；加入真实源码或测试文件后可以删除对应占位文件。

## 开始使用

当前没有已确认的安装、运行、构建或测试命令。创建正式 App 工程后，应在此补充经过实际验证的命令。

## 文档

从 [CONTEXT.md](CONTEXT.md) 查看项目当前状态和完整文档入口。
