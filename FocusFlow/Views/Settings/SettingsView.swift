import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                timerSection
                automationSection
                reminderSection
                appearanceSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .tint(FocusFlowTheme.accent)
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
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .alert("完成", isPresented: Binding(
                get: { successMessage != nil },
                set: { if !$0 { successMessage = nil } }
            )) {
                Button("好", role: .cancel) { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    private var timerSection: some View {
        Section("默认计时") {
            durationStepper("专注", keyPath: \.defaultFocusDuration, range: 1...180)
            durationStepper("短休息", keyPath: \.shortBreakDuration, range: 1...60)
            durationStepper("长休息", keyPath: \.longBreakDuration, range: 1...120)
            Stepper(value: $draft.longBreakInterval, in: 2...12) {
                LabeledContent("长休息间隔") { Text("每 \(draft.longBreakInterval) 个番茄") }
            }
        }
    }

    private var automationSection: some View {
        Section("专注流程") {
            Toggle("专注后自动开始休息", isOn: $draft.autoStartBreak)
            Toggle("休息后连续开始专注", isOn: $draft.continuousFocus)
            Toggle("计时时保持屏幕唤醒", isOn: $draft.keepScreenAwake)
        } footer: {
            Text("后台和锁屏后的剩余时间始终按系统日期重新计算，不依赖每秒定时器。")
        }
    }

    private var reminderSection: some View {
        Section("提醒与反馈") {
            Toggle("本地通知", isOn: $draft.notificationsEnabled)
            Toggle("系统提示音", isOn: $draft.soundEnabled)
            Toggle("震动反馈", isOn: $draft.hapticsEnabled)
            Toggle("中文语音播报", isOn: $draft.voiceEnabled)
            Button {
                container.speech.preview()
            } label: {
                Label("试听语音", systemImage: "speaker.wave.2.fill")
            }
            .disabled(!draft.voiceEnabled)
            .accessibilityHint("播放一段中文完成提醒")
        } footer: {
            Text("提示音和震动均调用 iOS 系统能力；白噪音由程序实时生成。")
        }
    }

    private var appearanceSection: some View {
        Section("外观与清单") {
            Picker("App 外观", selection: $draft.appearance) {
                Text("跟随系统").tag(AppAppearance.system)
                Text("浅色").tag(AppAppearance.light)
                Text("深色").tag(AppAppearance.dark)
            }
            NavigationLink {
                SettingsListManagerView()
            } label: {
                Label("自定义清单", systemImage: "folder.badge.gearshape")
            }
        }
    }

    private var dataSection: some View {
        Section("数据") {
            Button(action: prepareExport) {
                Label("导出 JSON 备份", systemImage: "square.and.arrow.up")
            }
            Button {
                isImporting = true
            } label: {
                Label("导入 JSON 备份", systemImage: "square.and.arrow.down")
            }
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("清除全部数据", systemImage: "trash")
            }
        } footer: {
            Text("数据只保存在本机 Application Support 目录。卸载 App 会删除这些数据，请定期备份。")
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("版本", value: versionText)
            Button {
                showPrivacy = true
            } label: {
                Label("隐私说明", systemImage: "hand.raised.fill")
            }
            LabeledContent("联网") { Text("无需联网") }
            LabeledContent("账号") { Text("无需登录") }
        }
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

private struct SettingsListManagerView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var editingList: TaskList?
    @State private var listToDelete: TaskList?

    var body: some View {
        List {
            Section {
                Label("收集箱", systemImage: "tray.fill")
                Label("今天", systemImage: "sun.max.fill")
                Label("计划", systemImage: "calendar")
                Label("已完成", systemImage: "checkmark.circle.fill")
            } header: {
                Text("内置视图")
            } footer: {
                Text("内置视图不会被删除。")
            }

            Section("自定义清单") {
                ForEach(container.store.lists.filter { !$0.isArchived }) { list in
                    Button { editingList = list } label: {
                        HStack(spacing: 12) {
                            Image(systemName: list.iconName)
                                .foregroundStyle(Color(hex: list.colorHex) ?? FocusFlowTheme.accent)
                                .frame(width: 28)
                            Text(list.name).foregroundStyle(FocusFlowTheme.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(FocusFlowTheme.tertiaryText)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { listToDelete = list } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("清单")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { editingList = TaskList(name: "") } label: { Image(systemName: "plus") }
                    .accessibilityLabel("创建清单")
            }
        }
        .sheet(item: $editingList) { list in
            SettingsListEditorView(list: list) { container.store.upsertList($0) }
        }
        .confirmationDialog(
            "删除这个清单？",
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除清单", role: .destructive) {
                if let list = listToDelete { container.store.deleteList(id: list.id) }
                listToDelete = nil
            }
            Button("取消", role: .cancel) { listToDelete = nil }
        } message: {
            Text("清单内的任务会保留，并移回收集箱。")
        }
    }
}

private struct SettingsListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let original: TaskList
    let onSave: (TaskList) -> Void

    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String

    private let icons = ["list.bullet", "briefcase.fill", "book.fill", "house.fill", "heart.fill", "figure.run", "lightbulb.fill", "star.fill"]
    private let colors = ["#22B88A", "#F06445", "#3978E8", "#F0A62E", "#8466DB", "#E04D77"]

    init(list: TaskList, onSave: @escaping (TaskList) -> Void) {
        original = list
        self.onSave = onSave
        _name = State(initialValue: list.name)
        _icon = State(initialValue: list.iconName)
        _colorHex = State(initialValue: list.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") { TextField("例如：工作", text: $name) }
                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(icons, id: \.self) { value in
                            Button { icon = value } label: {
                                Image(systemName: value)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(icon == value ? .white : FocusFlowTheme.secondaryText)
                                    .background(Circle().fill(icon == value ? (Color(hex: colorHex) ?? FocusFlowTheme.accent) : Color(uiColor: .tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(icon == value ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("颜色") {
                    HStack {
                        ForEach(colors, id: \.self) { value in
                            Button { colorHex = value } label: {
                                Circle()
                                    .fill(Color(hex: value) ?? FocusFlowTheme.accent)
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(.primary, lineWidth: colorHex == value ? 2 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("选择颜色")
                            .accessibilityAddTraits(colorHex == value ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle(original.name.isEmpty ? "新建清单" : "编辑清单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var result = original
                        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        result.iconName = icon
                        result.colorHex = colorHex
                        result.updatedAt = Date()
                        onSave(result)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
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
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

private extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let integer = UInt64(value, radix: 16) else { return nil }
        self.init(
            red: Double((integer >> 16) & 0xff) / 255,
            green: Double((integer >> 8) & 0xff) / 255,
            blue: Double(integer & 0xff) / 255
        )
    }
}
