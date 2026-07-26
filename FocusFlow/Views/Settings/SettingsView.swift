import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// 我的页：蓝紫标题栏 + 分组白卡彩色图标行，子设置以推入页承载。
struct SettingsView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var draft = AppSettings.default
    @State private var exportDocument: JSONBackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImport: AppData?
    @State private var showImportConfirmation = false
    @State private var showClearConfirmation = false
    @State private var showPrivacy = false
    @State private var showBackupDialog = false
    @State private var isHistoryPresented = false
    @State private var isListManagerPresented = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("我的")
                        accountCard
                        sectionLabel("外观 | 主题")
                        appearanceCard
                        sectionLabel("专注")
                        focusCard
                        versionFooter
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
            .background(FocusFlowTheme.pageBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { draft = container.store.settings }
            .onReceive(container.store.$data) { data in
                if draft != data.settings { draft = data.settings }
            }
            .onChange(of: draft) { newValue in
                container.updateSettings(newValue)
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: container.backup.suggestedFilename()
            ) { result in
                if case let .failure(error) = result { errorMessage = error.localizedDescription }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: handleImportSelection
            )
            .confirmationDialog(
                "备份与恢复",
                isPresented: $showBackupDialog,
                titleVisibility: .visible
            ) {
                Button("导出 JSON 备份", action: prepareExport)
                Button("导入 JSON 备份") { isImporting = true }
                Button("取消", role: .cancel) {}
            } message: {
                Text("数据只保存在本机，请定期导出备份。")
            }
            .confirmationDialog(
                "导入并覆盖当前数据？",
                isPresented: $showImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("导入备份", role: .destructive, action: confirmImport)
                Button("取消", role: .cancel) { pendingImport = nil }
            } message: {
                Text("当前任务、专注历史、清单和设置会被备份中的内容替换。")
            }
            .confirmationDialog(
                "清除全部本地数据？",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("永久清除", role: .destructive) { container.clearAllData() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("该操作无法撤销。建议先导出 JSON 备份。")
            }
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .sheet(isPresented: $isHistoryPresented) {
                FocusRecordListView(records: container.store.records, tasks: container.store.tasks)
            }
            .sheet(isPresented: $isListManagerPresented) {
                TaskListManagerView(
                    lists: container.store.lists.filter { !$0.isArchived },
                    onSave: { container.store.upsertList($0) },
                    onDelete: { container.store.deleteList(id: $0.id) }
                )
            }
            .alert("操作失败", isPresented: errorBinding) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .alert("完成", isPresented: successBinding) {
                Button("好", role: .cancel) { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ZStack {
            Text("我的")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            HStack {
                Spacer()
                Button {
                    showPrivacy = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("隐私说明")
            }
            .padding(.horizontal, 22)
        }
        .padding(.top, 6)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(FocusFlowTheme.banner.ignoresSafeArea(edges: .top))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(FocusFlowTheme.secondaryText)
            .padding(.leading, 8)
            .padding(.top, 6)
    }

    // MARK: - Cards

    private var accountCard: some View {
        SettingsCard {
            Button { showPrivacy = true } label: {
                SettingsRow(
                    icon: "person.crop.circle.fill",
                    tint: FocusFlowTheme.coral,
                    title: "账号",
                    trailingText: "本地模式 · 无需登录"
                )
            }
            .buttonStyle(.plain)
            rowDivider
            Button { showBackupDialog = true } label: {
                SettingsRow(
                    icon: "cloud.fill",
                    tint: FocusFlowTheme.sky,
                    title: "备份 | 恢复",
                    subtitle: "导出或导入 JSON 备份文件"
                )
            }
            .buttonStyle(.plain)
            rowDivider
            Button { isHistoryPresented = true } label: {
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    tint: FocusFlowTheme.sky,
                    title: "历史时间轴",
                    subtitle: "查看全部专注记录"
                )
            }
            .buttonStyle(.plain)
            rowDivider
            Button { showClearConfirmation = true } label: {
                SettingsRow(
                    icon: "trash.fill",
                    tint: FocusFlowTheme.coral,
                    title: "清除全部数据"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var appearanceCard: some View {
        SettingsCard {
            NavigationLink {
                AppearanceForm(draft: $draft)
            } label: {
                SettingsRow(
                    icon: "tshirt.fill",
                    tint: FocusFlowTheme.coral,
                    title: "背景海报和外观",
                    subtitle: "浅色 | 深色 | 跟随系统"
                )
            }
            .buttonStyle(.plain)
            rowDivider
            SettingsRow(
                icon: "paintpalette.fill",
                tint: FocusFlowTheme.coral,
                title: "主题颜色搭配",
                subtitle: "主题蓝紫",
                dotColor: FocusFlowTheme.accent,
                showsChevron: false
            )
            rowDivider
            Button { isListManagerPresented = true } label: {
                SettingsRow(
                    icon: "folder.fill.badge.gearshape",
                    tint: FocusFlowTheme.sky,
                    title: "清单管理",
                    subtitle: "新建、重命名、删除清单"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var focusCard: some View {
        SettingsCard {
            NavigationLink {
                TimerSettingsForm(draft: $draft)
            } label: {
                SettingsRow(
                    icon: "timer",
                    tint: FocusFlowTheme.accent,
                    title: "计时时长与自动化",
                    subtitle: "专注 / 休息时长、自动衔接"
                )
            }
            .buttonStyle(.plain)
            rowDivider
            NavigationLink {
                ReminderSettingsForm(draft: $draft, onPreviewVoice: { container.speech.preview() })
            } label: {
                SettingsRow(
                    icon: "bell.badge.fill",
                    tint: FocusFlowTheme.amber,
                    title: "提醒与反馈",
                    subtitle: "通知、提示音、震动、语音"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 62)
    }

    private var versionFooter: some View {
        HStack {
            Spacer()
            Text("FocusFlow \(versionText) · 无需联网 · 无需登录")
                .font(.caption2)
                .foregroundStyle(FocusFlowTheme.tertiaryText)
            Spacer()
        }
        .padding(.top, 16)
    }

    // MARK: - Actions

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )
    }

    private func prepareExport() {
        do {
            var snapshot = container.store.data
            snapshot.activeTimerSession = nil
            exportDocument = try container.backup.makeDocument(from: snapshot)
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let document = JSONBackupDocument(data: try Data(contentsOf: url))
            pendingImport = try container.backup.decode(AppData.self, from: document)
            showImportConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmImport() {
        guard let data = pendingImport else { return }
        do {
            try container.replaceData(data)
            draft = data.settings
            successMessage = "备份已导入。"
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingImport = nil
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - 行与卡片组件

private struct SettingsRow: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    var trailingText: String? = nil
    var dotColor: Color? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 21))
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(FocusFlowTheme.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(FocusFlowTheme.secondaryText)
                }
            }
            Spacer(minLength: 8)
            if let trailingText {
                Text(trailingText)
                    .font(.footnote)
                    .foregroundStyle(FocusFlowTheme.secondaryText)
            }
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 22, height: 22)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(uiColor: .systemGray3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FocusFlowTheme.cardBackground)
        )
    }
}

// MARK: - 子设置页

private struct TimerSettingsForm: View {
    @Binding var draft: AppSettings

    var body: some View {
        Form {
            Section("默认计时") {
                durationStepper("专注", keyPath: \.defaultFocusDuration, range: 1...180)
                durationStepper("短休息", keyPath: \.shortBreakDuration, range: 1...60)
                durationStepper("长休息", keyPath: \.longBreakDuration, range: 1...120)
                Stepper(value: $draft.longBreakInterval, in: 2...12) {
                    LabeledContent("长休息间隔") { Text("每 \(draft.longBreakInterval) 个番茄") }
                }
            }
            Section {
                Toggle("专注后自动开始休息", isOn: $draft.autoStartBreak)
                Toggle("休息后连续开始专注", isOn: $draft.continuousFocus)
                Toggle("计时时保持屏幕唤醒", isOn: $draft.keepScreenAwake)
            } header: {
                Text("自动化")
            } footer: {
                Text("后台和锁屏后的剩余时间始终按系统日期重新计算，不依赖每秒定时器。")
            }
        }
        .navigationTitle("计时与自动化")
        .navigationBarTitleDisplayMode(.inline)
        .tint(FocusFlowTheme.accent)
    }

    private func durationStepper(
        _ title: String,
        keyPath: WritableKeyPath<AppSettings, TimeInterval>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper(value: Binding(
            get: { max(Int(draft[keyPath: keyPath] / 60), range.lowerBound) },
            set: { draft[keyPath: keyPath] = TimeInterval($0 * 60) }
        ), in: range) {
            LabeledContent(title) {
                Text("\(Int(draft[keyPath: keyPath] / 60)) 分钟")
            }
        }
    }
}

private struct ReminderSettingsForm: View {
    @Binding var draft: AppSettings
    let onPreviewVoice: () -> Void

    var body: some View {
        Form {
            Section {
                Toggle("本地通知", isOn: $draft.notificationsEnabled)
                Toggle("系统提示音", isOn: $draft.soundEnabled)
                Toggle("震动反馈", isOn: $draft.hapticsEnabled)
                Toggle("中文语音播报", isOn: $draft.voiceEnabled)
                Button {
                    onPreviewVoice()
                } label: {
                    Label("试听语音", systemImage: "speaker.wave.2.fill")
                }
                .disabled(!draft.voiceEnabled)
            } header: {
                Text("提醒与反馈")
            } footer: {
                Text("提示音和震动均调用 iOS 系统能力；白噪音由程序实时生成。")
            }
        }
        .navigationTitle("提醒与反馈")
        .navigationBarTitleDisplayMode(.inline)
        .tint(FocusFlowTheme.accent)
    }
}

private struct AppearanceForm: View {
    @Binding var draft: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("App 外观", selection: $draft.appearance) {
                    Text("跟随系统").tag(AppAppearance.system)
                    Text("浅色").tag(AppAppearance.light)
                    Text("深色").tag(AppAppearance.dark)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("待办卡片使用内置渐变背景，不联网加载图片素材。")
            }
        }
        .navigationTitle("背景与外观")
        .navigationBarTitleDisplayMode(.inline)
        .tint(FocusFlowTheme.accent)
    }
}

private struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("本地优先", systemImage: "lock.shield.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(FocusFlowTheme.mint)
                    Text("FocusFlow 不要求账号，不上传任务、专注记录或设置，也不包含广告与跟踪 SDK。所有主要功能均可离线使用。")
                    Text("本地通知由 iOS 调度；中文语音使用系统语音合成；白噪音由设备实时生成。导出的 JSON 备份只在你选择的位置保存。")
                    Text("卸载 App 会清除沙盒内数据。请在卸载或更换设备前手动导出备份。")
                }
                .font(.body)
                .padding(22)
            }
            .navigationTitle("隐私说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
