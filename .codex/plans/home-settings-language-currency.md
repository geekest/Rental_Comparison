# 首页设置语言与货币

## 1. 任务目标

在原生 iOS App 的设置页面中提供语言和货币单位选择，并沿用现有本地工作区偏好持久化机制。

## 2. 当前状态

- `Rental_Comparison/RootView.swift` 已将 `SettingsView` 作为一级 Tab 展示。
- `Rental_Comparison/SettingsView.swift` 已支持默认货币 Picker，但语言没有设置项。
- `DecisionPreferences` 仅包含 `defaultCurrency`、默认居住月数和是否显示已淘汰房源。
- `AppStore.updatePreferences` 会把偏好保存到 `DecisionWorkspace`，旧数据解码依赖 Codable 默认值补齐新增字段。
- 现有 App 文案主要是中文，尚未建立完整本地化资源体系。

## 3. 目标状态

- 设置页“常用偏好”中可选择语言：简体中文、English。
- 设置页可选择默认货币单位，并继续支持人民币（CNY）、港币（HKD）和美元（USD）。
- 新偏好可保存、重新加载后保持；旧工作区数据仍可正常读取并默认使用简体中文。
- 交互控件具备稳定的 UI 测试标识或可通过可见文案定位。

## 4. 范围边界

### 本次包括

- 扩展偏好模型并保持 Codable 兼容。
- 更新设置页的语言和货币选择控件。
- 补充偏好持久化单元测试和设置页 UI 验证。

### 本次不包括

- 全 App 文案的完整本地化与 `.lproj` 资源建设。
- 汇率换算、跨货币比较或修改房源自身货币逻辑。
- 新增第三方依赖、修改数据库结构或生产配置。

## 5. 影响文件

- `Rental_Comparison/DecisionModels.swift`：新增语言偏好类型和默认值。
- `Rental_Comparison/SettingsView.swift`：增加语言 Picker，完善货币 Picker 的标识。
- `Rental_ComparisonTests/WorkspaceTests.swift`：验证语言和货币偏好保存。
- `Rental_ComparisonUITests/RentalComparisonUITests.swift`：验证设置页出现语言和货币控件。

## 6. 执行里程碑

### Milestone 1：理解现有实现

已完成：确认设置页、偏好保存链路和现有测试入口。

### Milestone 2：扩展偏好与设置 UI

实现 `AppLanguage` 和语言 Picker，保留现有货币选择并增加稳定标识。

验证：源码编译通过，设置页可构建。

### Milestone 3：补充测试并验证

更新单元测试和 UI 测试，运行 `xcodebuild test` 与 `git diff --check`。

## 7. 进度记录

- [x] 阅读相关文件
- [x] 确认当前实现
- [x] 完成方案设计
- [x] 修改核心逻辑
- [x] 补充测试
- [x] 运行验证
- [x] 完成复盘

## 8. 新发现与意外情况

- 发现：当前界面文案未接入本地化资源。
- 影响：本次语言选择可以持久化并作为后续本地化入口，但不能声称已完成全 App 语言切换。
- 处理方式：控制范围，只交付设置项和偏好存储，不静默扩大为全量翻译。
- 发现：Xcode 运行测试时反复尝试连接一台锁屏实体 iPhone。
- 影响：全量 XCTest 和单独单元测试均未获得最终通过结果，测试协调器被中断。
- 处理方式：确认编译阶段无 Swift 错误；保留测试代码，待设备解锁或移除该运行目标后重跑。

## 9. 决策记录

### Decision：复用现有 DecisionPreferences

选择：在现有工作区偏好中新增语言字段。

原因：设置页已经使用该模型和 `AppStore.updatePreferences`，可以最小化改动并自动兼容旧数据。

备选方案：使用系统 `AppStorage` 或新增独立设置服务。

影响：语言与货币和其他工作区偏好一样随工作区保存，暂不影响系统语言或全 App 文案。

## 10. 验证计划

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Rental_Comparison.xcodeproj -scheme Rental_Comparison -destination 'platform=iOS Simulator,name=iPhone 16e' test`
- `git diff --check`
- 检查单元测试验证语言与货币保存，UI 测试验证设置页控件存在。

验证结果：源码编译阶段通过；`git diff --check` 通过；测试执行因锁屏实体设备导致 Xcode 测试协调器中断。

## 11. 风险与回滚

- 风险：若未来直接声称支持全 App 切换语言，会与当前硬编码中文文案不一致。
- 回滚：删除新增偏好字段和设置控件即可；旧工作区 Codable 默认值保持兼容。
