# 原生 App 图标交付

## 1. 任务目标

为 Rental Comparison 原生 iOS App 接入用户选定的第 3 号图标方向：由两条圆润拱形组成居所负形，表达“在候选方案之间比较并形成自主决策”。完成后，Xcode Target 将能使用默认与暗黑外观的 App Icon，并通过隔离分支提交和创建 PR。

## 2. 当前状态

- `Rental_Comparison.xcodeproj` 的 Debug 与 Release 均指定 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`，但仓库尚无 `Assets.xcassets` 或 `AppIcon`。
- `project.yml` 是 XcodeGen 工程声明，`Rental_Comparison/` 目录已作为 App Target 的源目录。
- 本机使用 Xcode 26.3；官方允许 iOS App Icon 使用单一 1024×1024 资源，并在 Asset Catalog 中提供 Dark 变体。

## 3. 目标状态

- 新增标准 `Assets.xcassets/AppIcon.appiconset`，其中包含默认和 Dark 两张 1024×1024 PNG。
- 图形保持相同结构：蓝、珊瑚两条圆润拱形交叠，中央留出居所负形；暗黑版使用深蓝背景和克制配色。
- XcodeGen 重新生成工程后，App Target 编译时能识别 `AppIcon`。

## 4. 范围边界

### 本次包括

- 生成并审阅默认、暗黑 App Icon 主图。
- 接入 iOS Asset Catalog 和 Xcode 工程。
- 运行资源编译、原生构建与相关测试，提交、推送和创建 PR。

### 本次不包括

- 修改 App 内界面、品牌文案或启动页。
- 引入 Icon Composer 分层 `.icon` 文件、替代图标或 Mono/Tinted 自定义资源。
- 修改 Web 原型资源。

## 5. 影响文件

- `Rental_Comparison/Assets.xcassets/`：新增默认与暗黑 App Icon 资源。
- `project.yml`：如 XcodeGen 未自动发现 Asset Catalog，再最小化声明资源。
- `Rental_Comparison.xcodeproj/project.pbxproj`：由 XcodeGen 生成，引用 Asset Catalog。
- `.codex/plans/app-icon-design.md`：记录本任务计划、发现和复盘。

## 6. 执行里程碑

### Milestone 1：生成与审阅源图

要做：生成第 3 号方向的默认和暗黑 1024×1024 图标源图。

验证：检查尺寸、PNG 格式、相同几何结构、深浅对比和小尺寸可辨识度。

完成标准：两张主图均可直接放入 App Icon 资源集。

### Milestone 2：接入资源和工程

要做：建立 Asset Catalog、配置 `AppIcon` 的 Any/Dark 外观并重新生成工程。

验证：`actool` 与 Xcode 项目能识别资源，`ASSETCATALOG_COMPILER_APPICON_NAME` 仍为 `AppIcon`。

完成标准：App Target 包含可编译的图标资源。

### Milestone 3：验证与发布

要做：运行原生构建和测试、审查 diff、提交、推送并创建中文 Draft PR。

验证：构建和测试成功，PR 指向 `main` 且仅包含本任务文件。

完成标准：PR 可供审查。

## 7. 进度记录

- [x] 阅读项目、Apple 图标规范和 GitHub 发布流程。
- [x] 确认项目没有既有 App Icon，创建隔离工作树。
- [x] 生成并审阅默认与暗黑源图。
- [x] 接入 Asset Catalog 并重新生成 Xcode 工程。
- [x] 运行资源、构建与测试验证。
- [ ] 审查 diff、提交、推送并创建 PR。
- [ ] 完成复盘。

## 8. 新发现与意外情况

- 发现：本机默认开发者目录指向 Command Line Tools。
- 影响：原生验证命令必须显式设置 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- 处理方式：所有 Xcode 与 `actool` 命令均使用该环境变量。

- 发现：`assetutil` 在编译后的 `Assets.car` 中显示 `AppIcon` 的 `UIAppearanceAny` 与 `UIAppearanceDark` 条目，且两者均为 1024×1024。
- 影响：Dark 变体不是仅在源目录声明，已由 Xcode 编译进应用资源。
- 处理方式：将该检查作为本次交付的暗黑外观验证证据。

## 9. 决策记录

### Decision：使用 Asset Catalog 而非 Icon Composer

选择：使用 `AppIcon.appiconset` 的 Any/Dark 变体。

原因：项目最低支持 iOS 17；Asset Catalog 是 Xcode 支持的标准图标交付格式，能够在不改变部署策略的前提下提供默认和暗黑资源，并由 Xcode 自动生成尺寸变体。

备选方案：使用 Icon Composer 的分层 `.icon` 文件。

影响：不提供自定义 Liquid Glass、Mono 或 Tinted 图层效果；较新的系统会为未定制的变体自动处理，且避免引入无法通过 CLI 可重复生成的二进制编辑产物。

## 10. 验证计划

- `sips -g pixelWidth -g pixelHeight -g format`：确认两张 PNG 均为 1024×1024。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun actool ...`：确认 Asset Catalog 编译成功。
- `xcodegen generate`：确认生成工程引用 Asset Catalog。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ... build`：确认原生构建成功。
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ... test`：运行原生测试。
- `git diff --check` 与定向 `git diff`：确认无格式问题和无关改动。

## 11. 风险与回滚

- 风险：iOS 17 不显示 Home Screen 的 Dark App Icon 外观；资源仍可安全编译，支持该外观的新系统会使用 Dark 变体。
- 风险：图像生成无法提供 Icon Composer 的真实动态材质；以扁平源图保留系统后续材质处理空间。
- 回滚：删除新增 `Assets.xcassets`，重新运行 `xcodegen generate`，即可恢复没有 App Icon 资源的当前状态。

## 12. 最终结果与复盘

- 实际完成：新增用户选定的双拱居所图标，默认版使用浅蓝背景、蓝色与珊瑚色前景；暗黑版使用深海军蓝背景并保持相同几何结构。
- 修改文件：新增 `Rental_Comparison/Assets.xcassets/`，并由 XcodeGen 更新 `Rental_Comparison.xcodeproj/project.pbxproj`；本计划随 PR 一并交付。
- 验证：`jq empty`、`sips` 尺寸检查、`xcodegen generate`、`xcodebuild build`、`assetutil --info`、`xcodebuild test` 均成功。业务单测 7 个与 UI 测试 2 个均通过。
- 未验证：未在真实 iPhone Home Screen 手动切换 Dark App Icon；iOS 17 不显示该 Home Screen 外观，新系统会使用编译出的 Dark 资源。
- 后续：无须更新 `AGENTS.md`；本次没有形成新的稳定工程规则。
