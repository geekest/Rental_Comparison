# 原生 iOS 全球化语言切换

## 1. 任务目标

修复语言设置只保存、不驱动页面的问题。原生 iOS App 的所有用户可见静态文案支持简体中文、英语、日语和繁体中文；切换后立即生效，重启后保持。用户输入的房源名称、地址和外部来源内容保持原文。

## 2. 当前状态

- 当前分支实际没有 `AppLanguage` 或 `DecisionPreferences.language` 字段，设置页也没有语言 Picker；上一轮旧快照中的语言持久化实现不在当前工作树。
- `AppStore.updatePreferences` 会持久化偏好，但根视图未注入 `\.locale`。
- `Rental_Comparison/` 约有 256 处 SwiftUI 外显字符串，主要硬编码为中文。
- 当前没有 `.lproj`、`Localizable.strings` 或 String Catalog。
- 现有测试只验证语言偏好持久化，没有验证页面文案切换。
- `web_version/` 是历史 Web 原型，本次不纳入范围。

## 3. 目标状态

- `AppLanguage` 支持 `zh-Hans`、`en`、`ja`、`zh-Hant`，并映射到 SwiftUI `Locale`。
- 根视图由当前偏好驱动语言环境，设置改变后立即重绘。
- 所有 App 自有静态文案进入系统本地化资源；数量、日期、货币和复数遵循当前语言。
- 旧工作区解码缺失新字段时默认简体中文。

## 4. 范围边界

### 本次包括

- 原生 iOS App 的语言模型、持久化兼容、SwiftUI locale 驱动。
- `Rental_Comparison/` 全部用户可见静态文案及动态组合文案。
- 四种语言资源、设置选项、单元测试和 UI 回归测试。

### 本次不包括

- `web_version/` 国际化。
- 用户输入、房源原始证据和外部来源内容的翻译。
- 第三方本地化依赖、业务流程和视觉重构。

## 5. 影响文件

- `Rental_Comparison/DecisionModels.swift`：语言枚举与 locale 映射。
- `Rental_Comparison/RentalComparisonApp.swift` / `RootView.swift`：根级语言环境。
- `Rental_Comparison/SettingsView.swift`：四种语言选项与设置页文案。
- `Rental_Comparison/*.swift`：用户可见文案本地化。
- `Rental_Comparison/Resources/`：四种语言资源。
- `Rental_ComparisonTests/`、`Rental_ComparisonUITests/`：回归测试。
- `Rental_Comparison.xcodeproj/project.pbxproj`：资源 Target membership（如需要）。

## 6. 执行里程碑

### Milestone 1：建立语言驱动链路

- 扩展语言枚举，映射 locale。
- 根视图注入 locale，确保设置变化立即生效。
- 验证四种语言标识和偏好持久化。

### Milestone 2：完成静态文案资源

- 使用系统 `.strings` 资源，不新增第三方依赖。
- 覆盖导航、表单、按钮、状态、错误提示和弹窗。
- 静态扫描确认无遗漏的用户可见硬编码中文。

### Milestone 3：处理动态文案和格式

- 处理动态数量、日期、货币、复数和组合句。
- 用户数据不进入翻译资源。

### Milestone 4：回归验证

- 运行单元测试、UI 测试和 iOS 构建。
- 验证四种语言的设置页、首页、待确认页、对比页和编辑流程。
- 更新本计划结果与未验证项。

## 7. 进度记录

- [x] 阅读项目规则、上下文和计划规范
- [x] 确认当前语言持久化链路与外显文案规模
- [x] 确认使用系统本地化能力、不新增第三方依赖
- [x] 完成语言驱动链路
- [ ] 完成四种语言全部文案资源
- [x] 补充回归测试
- [x] 运行构建、测试和静态扫描
- [ ] 完成复盘

## 8. 新发现与意外情况

- 发现：当前分支没有语言枚举、语言偏好字段或语言 Picker，且没有本地化资源。
  影响：需要新增完整语言设置链路，不能只修复环境注入。
  处理：按完整国际化链路实施。
- 发现：当前工作树的 Git index 原本处于未完成合并状态，多个文件存在 `UU`；文件内容同时含有冲突标记。
  影响：直接生成 Xcode 工程会继承冲突文本，影响审查和后续构建。
  处理：清理明确冲突标记并保留当前可构建实现；未执行 `git add`、commit 或分支操作。
- 发现：静态外显文案还包含动态组合句、报告 HTML 和模型派生标题，尚未全部接入资源。
  影响：当前验证覆盖语言驱动和核心设置/导航文案，但不能声称全 App 文案已 100% 本地化。
  处理：保留为后续里程碑，不把本次结果标记为完整全球化交付。
- 发现：现有 UI 测试包含简体中文断言。
  影响：需要保留中文场景并新增多语言断言，避免测试依赖默认语言。
  处理：调整测试启动参数和断言范围。

## 9. 决策记录

### Decision：使用系统本地化能力

选择：使用 Xcode `.strings` 资源和 SwiftUI `\.locale`。

原因：与原生 SwiftUI、系统格式化和 App Store 本地化链路一致，减少依赖。

备选：自建字典或第三方框架。

影响：需要整理现有文案资源，但后续扩展语言成本较低。

## 10. 验证计划

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,name=iPhone 16e' test`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,name=iPhone 16e' build`
- 静态扫描原生 SwiftUI 外显硬编码，排除用户数据、fixture 和测试内容。
- UI 路径：设置 → 语言 → English / 日本語 / 繁體中文 → 检查 Tab、导航和设置文案 → 重启检查保持。

## 11. 风险与回滚

- 大量文案替换可能遗漏弹窗或动态组合字符串；使用逐文件扫描和四语言冒烟验证缓解。
- 资源 key 错误可能回退为 key；构建和四语言运行检查资源。
- 旧工作区缺失语言字段；保留 Codable 默认值为简体中文。
- 回滚只涉及代码和资源，不改变业务数据格式。

## 12. 最终结果与复盘

已完成语言驱动链路、四语言资源骨架、核心页面文案和回归验证；全量动态文案本地化仍待继续。当前未执行 `git add`、commit 或 PR 操作；工作树仍保留原有 `UU` 索引状态及 Xcode 用户状态目录。
