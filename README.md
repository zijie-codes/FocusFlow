# FocusFlow（番茄专注）

FocusFlow 是一个面向 iPhone 的本地优先专注工具，包含任务管理、可靠番茄计时、重复规则、统计反馈、中文语音播报、本地通知、数据备份和程序化白噪音。工程使用 SwiftUI 编写，并通过 XcodeGen 从 `project.yml` 生成 Xcode 工程。

## 环境要求

- 应用最低系统版本：iOS 16.0
- macOS 构建：Xcode 15 或更新版本、XcodeGen
- Windows：可编辑、提交、校验源码，但不能在本机运行 Xcode 或生成 iOS 安装包
- Python 3：仅用于执行无第三方依赖的仓库校验脚本

## 在 Windows 上开发

Windows 上可以使用任意编辑器维护 Swift 源码和配置，并先执行结构校验：

```powershell
python scripts/validate-project.py
git add .
git commit -m "Update FocusFlow"
git push
```

推送后，GitHub Actions 会在 macOS Runner 上完成 Xcode 工程生成、模拟器测试和无签名 IPA 打包。iOS 的编译、模拟器测试、签名与真机调试仍必须在 macOS/Xcode 环境进行。

## 在 macOS 上生成和运行

```bash
brew install xcodegen
python3 scripts/validate-project.py
xcodegen generate --spec project.yml
open FocusFlow.xcodeproj
```

在 Xcode 中选择 `FocusFlow` Scheme 和目标模拟器即可运行。`FocusFlow.xcodeproj` 是生成文件，不提交到仓库；每次修改 `project.yml` 后重新运行 `xcodegen generate`。

## GitHub Actions 与无签名 IPA

工作流位于 `.github/workflows/build-unsigned-ipa.yml`，可通过以下方式触发：

- 推送到 `main` 或 `master`
- 创建或更新 Pull Request
- 在 GitHub 的 **Actions → Build and test unsigned IPA → Run workflow** 中手动运行

工作流会：

1. 安装 XcodeGen 并生成 `FocusFlow.xcodeproj`。
2. 从 Runner 当前可用设备中动态选择一个 iPhone Simulator。
3. 在模拟器上执行 `FocusFlowTests`。
4. 使用 `CODE_SIGNING_ALLOWED=NO` 为 `iphoneos` 构建 Release App。
5. 按 `Payload/FocusFlow.app` 结构打包 `FocusFlow-unsigned.ipa`。
6. 上传名为 `FocusFlow-unsigned-ipa` 的 GitHub Actions Artifact（保留 14 天）。

## 签名与安装

工作流产出的 IPA **没有代码签名，不能直接安装到普通 iPhone 或 iPad**。它主要用于验证设备构建和作为后续签名的输入。

安装到真机前必须使用与你设备和 Bundle ID 匹配的 Apple 开发证书及 Provisioning Profile 重新签名。常见方式包括：

- 在 macOS 上打开生成的工程，在 Xcode 的 Signing & Capabilities 中选择开发团队并直接运行到设备。
- 使用自己的证书和描述文件对 Artifact 重新签名，再通过合规的内部发布或测试渠道安装。
- 使用 AltStore、Sideloadly 等侧载工具以自己的 Apple ID 重新签名；免费开发配置通常需要定期续签。
- App Store 或 TestFlight 分发必须使用有效的 Apple Developer Program 账号，并按 Apple 流程 Archive、签名和上传。

请勿把 `.p12`、`.mobileprovision`、私钥或密码提交到仓库。若后续需要在 CI 中自动签名，应使用 GitHub Actions Secrets 和受保护的发布工作流。

## 隐私说明

当前仓库没有自建后端或第三方分析 SDK，核心任务、计时和偏好数据由应用在设备本地管理。用户主动执行的备份导出由用户自行选择保存或分享位置。

- 中文语音播报使用 iOS 自带的 `AVSpeechSynthesizer`，不录音，也不申请麦克风或语音识别权限。
- 提醒使用 iOS 本地通知，只有用户授权后才会显示。
- 白噪音由 `WhiteNoiseService` 通过系统音频能力在运行时程序化生成，不需要下载、上传或在仓库中存放循环音频文件。
- 仓库不会保存 Apple 签名证书、描述文件或用户备份数据。

正式发布前，请根据实际接入的服务、Apple 隐私清单要求和 App Store Connect 数据收集问卷更新本节及产品隐私政策。

## 目录结构

```text
FocusFlow/
├─ App/                     应用入口、依赖容器和 AppDelegate
├─ Models/                  领域模型与重复规则
├─ Persistence/             本地数据存储
├─ Services/                通知、语音、备份、反馈和白噪音服务
├─ Timer/                   专注计时引擎
├─ ViewModels/              页面状态与业务编排
├─ Views/                   SwiftUI 页面和设计系统
└─ Resources/Assets.xcassets/
                             App 图标与资产目录
FocusFlowTests/             XCTest 单元测试
scripts/                    跨平台仓库校验脚本
.github/workflows/          macOS CI 与无签名 IPA 打包
project.yml                 XcodeGen 工程定义
```

## 白噪音资源

白噪音不是预先录制的音频资产。应用启动白噪音功能时，由 `FocusFlow/Services/WhiteNoiseService.swift` 在运行时生成音频信号并交给系统音频引擎播放。因此仓库体积更小，也不会引入音频素材授权问题。若调整生成算法，请同时在真机上检查音量、耳机切换、来电/音频会话中断和前后台行为。

## 提交前校验

```bash
python3 scripts/validate-project.py
```

脚本会检查关键 Swift 源文件、测试目录、App Icon、资产 JSON、`project.yml` 的 iOS 16 应用/测试目标，以及 CI 中测试、无签名设备构建、Payload 打包和 Artifact 上传所需的关键配置。

## 后续修改入口

- 调整默认专注/休息设置：`FocusFlow/Models/DomainModels.swift` 的 `AppSettings` 默认值。
- 调整视觉颜色、圆角和卡片：`FocusFlow/Views/Shared/DesignSystem.swift`。
- 调整计时恢复、暂停或完成规则：`FocusFlow/Timer/TimerEngine.swift` 与 `FocusFlow/App/AppContainer.swift`，并同步增加 `FocusFlowTests/TimerEngineTests.swift`。
- 调整任务字段或备份结构：先更新模型与 `AppData.currentSchemaVersion`，再为旧 JSON 增加兼容解码。
- 调整 Actions 打包：修改 `.github/workflows/build-unsigned-ipa.yml`；设备 App 固定从 `Release-iphoneos/FocusFlow.app` 打入 `Payload`。
