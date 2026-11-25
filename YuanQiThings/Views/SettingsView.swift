import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: EnergyStore
    @AppStorage("yuanqi.haptics.enabled") private var hapticsEnabled = true
    @AppStorage("yuanqi.reminder.enabled") private var reminderEnabled = false
    @AppStorage("yuanqi.reminder.hour") private var reminderHour = 20
    @AppStorage("yuanqi.reminder.minute") private var reminderMinute = 0
    @State private var reminderMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                sectionTitle("数据与同步")
                settingsCard {
                    NavigationLink { DataAndSyncView() } label: {
                        settingRow(
                            "iCloud 同步",
                            symbol: "icloud.fill",
                            tint: AppTheme.rose,
                            detail: store.cloudSyncState.shortTitle
                        )
                    }
                }

                sectionTitle("提醒与体验")
                settingsCard {
                    VStack(spacing: 0) {
                        HStack(spacing: 13) {
                            settingIcon("bell.fill", tint: AppTheme.rose)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("每日提醒").foregroundStyle(AppTheme.cocoa)
                                if reminderEnabled {
                                    Text(reminderTime.formatted(date: .omitted, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Toggle("每日提醒", isOn: $reminderEnabled).labelsHidden().tint(AppTheme.rose)
                        }
                        .padding(.vertical, 12)

                        if reminderEnabled {
                            Divider().padding(.leading, 54)
                            DatePicker("提醒时间", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                                .tint(AppTheme.rose)
                                .padding(.vertical, 12)
                        }

                        Divider().padding(.leading, 54)
                        HStack(spacing: 13) {
                            settingIcon("waveform", tint: AppTheme.lavender)
                            Text("触感反馈").foregroundStyle(AppTheme.cocoa)
                            Spacer()
                            Toggle("触感反馈", isOn: $hapticsEnabled).labelsHidden().tint(AppTheme.rose)
                        }
                        .padding(.vertical, 12)
                    }
                }

                sectionTitle("关于")
                settingsCard {
                    VStack(spacing: 0) {
                        NavigationLink { HelpView() } label: {
                            settingRow("使用帮助", symbol: "questionmark.circle.fill", tint: AppTheme.rose)
                        }
                        rowDivider
                        NavigationLink { PrivacyPolicyView() } label: {
                            settingRow("隐私政策", symbol: "shield.lefthalf.filled", tint: .orange)
                        }
                        rowDivider
                        NavigationLink { TermsView() } label: {
                            settingRow("使用条款", symbol: "doc.text.fill", tint: AppTheme.lavender)
                        }
                        rowDivider
                        Link(destination: URL(string: "mailto:aprilshujiang@163.com")!) {
                            settingRow("联系我们", symbol: "envelope.fill", tint: AppTheme.rose)
                                .accessibilityLabel(Text("联系邮箱 aprilshujiang@163.com"))
                        }
                    }
                }
                Text("版本 \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: reminderEnabled) { _, enabled in updateReminder(enabled: enabled) }
        .onChange(of: reminderHour) { _, _ in if reminderEnabled { updateReminder(enabled: true) } }
        .onChange(of: reminderMinute) { _, _ in if reminderEnabled { updateReminder(enabled: true) } }
        .onChange(of: hapticsEnabled) { _, enabled in
            guard enabled else { return }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred(intensity: 0.8)
        }
        .task {
            if reminderEnabled, !(await ReminderScheduler.isAuthorized()) {
                reminderEnabled = false
            }
        }
        .alert("每日提醒", isPresented: Binding(
            get: { reminderMessage != nil },
            set: { if !$0 { reminderMessage = nil } }
        )) { Button("好") { reminderMessage = nil } } message: { Text(reminderMessage ?? "") }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("把生活过成喜欢的样子")
                    .font(.headline).foregroundStyle(AppTheme.cocoa)
                Text("照顾数据，也照顾你的使用感受")
                    .font(.caption).foregroundStyle(AppTheme.cocoa.opacity(0.58))
            }
            Spacer()
            ZStack {
                Circle().fill(AppTheme.blush).frame(width: 82, height: 82)
                Image(systemName: "heart.fill")
                    .font(.system(size: 34)).foregroundStyle(AppTheme.rose.opacity(0.82))
                Image(systemName: "sparkle")
                    .foregroundStyle(AppTheme.gold).offset(x: 31, y: -29)
            }
        }
        .padding(18)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.94)) }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.headline).foregroundStyle(AppTheme.cocoa.opacity(0.62)).padding(.leading, 6)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().padding(.horizontal, 16)
            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.96)) }
            .shadow(color: AppTheme.rose.opacity(0.06), radius: 11, y: 4)
    }

    private func settingRow(_ title: LocalizedStringKey, symbol: String, tint: Color, detail: String? = nil) -> some View {
        HStack(spacing: 13) {
            settingIcon(symbol, tint: tint)
            Text(title).foregroundStyle(AppTheme.cocoa)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14).contentShape(Rectangle())
    }

    private func settingIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 36, height: 36).background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 11))
    }

    private var rowDivider: some View { Divider().padding(.leading, 54) }
    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    private var reminderTime: Date {
        Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(get: { reminderTime }, set: {
            reminderHour = Calendar.current.component(.hour, from: $0)
            reminderMinute = Calendar.current.component(.minute, from: $0)
        })
    }

    private func updateReminder(enabled: Bool) {
        Task {
            let result = await ReminderScheduler.update(enabled: enabled, hour: reminderHour, minute: reminderMinute)
            if enabled && !result {
                reminderEnabled = false
                reminderMessage = "请在系统“设置”中允许元气小事发送通知，再回来开启每日提醒。"
            }
        }
    }
}

struct DataAndSyncView: View {
    @EnvironmentObject private var store: EnergyStore
    @State private var document: SettingsBackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmingRestore = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 14) {
                    Image(systemName: store.cloudSyncState.symbol)
                        .font(.system(size: 38)).foregroundStyle(AppTheme.rose)
                        .frame(width: 78, height: 78).background(AppTheme.blush, in: Circle())
                    Text("iCloud 状态").font(.headline).foregroundStyle(AppTheme.cocoa)
                    Text(store.cloudSyncState.shortTitle).font(.title3.bold()).foregroundStyle(AppTheme.rose)
                    if case .synced(let date) = store.cloudSyncState {
                        Text("上次同步 \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if case .failed(let reason) = store.cloudSyncState {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.cocoa.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button { store.syncCloudNow() } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(AppTheme.rose, in: Capsule())
                    }
                    .buttonStyle(.plain).disabled(store.cloudSyncState == .syncing || !store.isReady)
                }
                .padding(20).background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 0) {
                    actionRow("导出本地备份", symbol: "square.and.arrow.up") { exportBackup() }
                    Divider().padding(.leading, 54)
                    actionRow("从文件恢复", symbol: "square.and.arrow.down") { confirmingRestore = true }
                }
                .disabled(!store.isReady)
                .padding(.horizontal, 16).background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))

                Label("打卡记录保存在本机；iCloud 同步成功后，你的私人 iCloud 中也会有一份副本。暂时无法同步时仍可在本机打卡。", systemImage: "info.circle.fill")
                    .font(.footnote).foregroundStyle(AppTheme.cocoa.opacity(0.62))
                    .padding(16).background(AppTheme.blush.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(18)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("数据与同步").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: backupFilename) { result in
            if case .failure = result { message = "备份未导出，请重试" }
            document = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { importBackup($0) }
        .confirmationDialog("从文件恢复", isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("选择备份文件", role: .destructive) { importing = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("恢复会先用备份替换本机的小事和打卡记录，随后尝试与 iCloud 合并同步。建议先导出当前记录。")
        }
        .alert("数据与同步", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func actionRow(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.title3).foregroundStyle(AppTheme.rose)
                    .frame(width: 36, height: 36).background(AppTheme.blush, in: RoundedRectangle(cornerRadius: 10))
                Text(title).foregroundStyle(AppTheme.cocoa)
                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }.padding(.vertical, 13)
        }.buttonStyle(.plain)
    }

    private var backupFilename: String { "元气小事备份-\(Date.now.formatted(.iso8601.year().month().day()))" }
    private func exportBackup() {
        do { document = SettingsBackupDocument(data: try store.makeBackupData()); exporting = true }
        catch { message = "生成备份失败，请重试" }
    }
    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            try store.restoreBackup(from: Data(contentsOf: url)); message = "备份已恢复，打卡记录和小事已更新"
        } catch { message = "无法读取这个备份文件" }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ArticlePage(title: "隐私政策", symbol: "shield.lefthalf.filled") {
            ArticleSection("我们保存什么", "元气小事保存你创建的小事、打卡日期和应用偏好，不需要注册账号。")
            ArticleSection("数据保存位置", "数据保存在这台设备上。iCloud 同步成功后，小事和打卡记录也会存入你的私人 iCloud 容器。开发者不会将这些数据用于广告或跟踪。")
            ArticleSection("你的选择", "你可以在系统设置中关闭 iCloud 或管理通知权限，也可以导出本地备份。")
        }
    }
}

struct HelpView: View {
    var body: some View {
        ArticlePage(title: "使用帮助", symbol: "questionmark.circle.fill") {
            ArticleSection("如何打卡", "在“今日”页点一下小事即可获得 +1 元气；再次点击可以取消。")
            ArticleSection("如何补记", "在“今日”页选择过去的日期，再点击小事补记。在“日历”页点击日期可查看当天记录。")
            ArticleSection("小组件没有更新", "打开 App 查看首页记录，再回到桌面查看小组件。小组件读取同一设备上的共享记录，无需单独登录 iCloud。")
            ArticleSection("如何保护记录", "保持 iCloud 同步开启，并定期在“数据与同步”中导出一份本地备份。")
        }
    }
}

struct TermsView: View {
    var body: some View {
        ArticlePage(title: "使用条款", symbol: "doc.text.fill") {
            ArticleSection("温柔记录，不是医疗建议", "元气小事用于个人生活记录和自我鼓励，不提供医疗、心理诊断或治疗建议。")
            ArticleSection("你的记录", "你应当妥善保护自己的设备、iCloud 账户及导出的备份文件。")
            ArticleSection("服务可用性", "iCloud 同步和通知依赖 Apple 系统服务、网络以及用户授予的权限。")
        }
    }
}

private struct ArticlePage<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder let content: Content
    init(title: LocalizedStringKey, symbol: String, @ViewBuilder content: () -> Content) { self.title = title; self.symbol = symbol; self.content = content() }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: symbol).font(.system(size: 42)).foregroundStyle(AppTheme.rose)
                    .frame(width: 88, height: 88).background(AppTheme.blush, in: Circle())
                content
            }.padding(18)
        }.background(AppTheme.background.ignoresSafeArea()).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct ArticleSection: View {
    let title: LocalizedStringKey; let text: LocalizedStringKey
    init(_ title: LocalizedStringKey, _ text: LocalizedStringKey) { self.title = title; self.text = text }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(AppTheme.cocoa)
            Text(text).font(.body).foregroundStyle(AppTheme.cocoa.opacity(0.66)).fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct SettingsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private enum ReminderScheduler {
    static let identifier = "yuanqi.daily.reminder"
    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    static func update(enabled: Bool, hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return true }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { return false }
            let content = UNMutableNotificationContent()
            content.title = "今天也收集一点元气吧"
            content.body = "完成一件喜欢的小事，就是一个值得庆祝的小胜利。"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            return true
        } catch { return false }
    }
}

private extension CloudSyncState {
    var shortTitle: String {
        switch self {
        case .checking: String(localized: "检查中")
        case .syncing: String(localized: "同步中")
        case .synced: String(localized: "已同步")
        case .signedOut: String(localized: "未登录")
        case .unavailable: String(localized: "暂不可用")
        case .failed: String(localized: "同步失败")
        }
    }
}
