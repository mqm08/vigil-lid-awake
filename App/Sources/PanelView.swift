import SwiftUI

struct PanelView: View {
    @EnvironmentObject var store: Store

    @AppStorage("showSettings") private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            header
            content
            footer
        }
        .padding(14)
        .frame(width: 344)
    }

    private var content: some View {
        VStack(spacing: 12) {
            HeroCard()
            if store.hasConflict { ConflictBanner() }
            if store.daemonOutdated { UpdateBanner() }
            MetricsRow()
            KeepModeCard()
            settingsToggle
            if showSettings {
                FitScrollView(maxHeight: maxSettingsHeight) {
                    VStack(spacing: 12) {
                        SafetyCard()
                        AutomationCard()
                    }
                }
            }
        }
    }

    /// Everything above the settings is ~430pt; keep the whole panel on screen.
    private var maxSettingsHeight: CGFloat {
        let screen = NSScreen.main?.visibleFrame.height ?? 800
        return max(200, screen - 560)
    }

    private var settingsToggle: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { showSettings.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                Text(showSettings ? "收起设置" : "安全保护与更多设置")
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(showSettings ? 180 : 0))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Color.primary.opacity(0.045)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("守夜").font(.system(size: 15, weight: .bold))
                Text("Vigil · 合上盖子,我替你守着")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.daemonHealthy ? Color.green : (store.daemonInstalled ? .orange : .red))
                .frame(width: 7, height: 7)
            Text(store.daemonHealthy ? "后台服务运行中"
                 : store.daemonInstalled ? "后台服务无响应" : "后台服务未安装")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("查看日志") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/var/log/vigil.log"))
                }
                Button("GitHub 主页") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/mqm08/vigil-lid-awake")!)
                }
                Divider()
                Button("卸载守夜…", role: .destructive) { confirmUninstall() }
                Divider()
                Button("退出") { store.quit() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}

extension PanelView {
    private func confirmUninstall() {
        let alert = NSAlert()
        alert.messageText = "卸载守夜?"
        alert.informativeText = "会移除后台服务、设置和应用本身,休眠行为恢复为系统默认。"
        alert.addButton(withTitle: "卸载")
        alert.addButton(withTitle: "取消")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.uninstallEverything()
        }
    }
}

/// A ScrollView that is only as tall as its content, up to `maxHeight`.
struct FitScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content()
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
                })
        }
        .scrollIndicators(.automatic)
        .frame(height: min(max(contentHeight, 1), maxHeight))
        .onPreferenceChange(HeightKey.self) { contentHeight = $0 }
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct UpdateBanner: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundStyle(Theme.emberDeep)
            Text("后台服务有新版本").font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            Button(store.isInstalling ? "更新中…" : "更新") { store.installDaemon() }
                .buttonStyle(.borderedProminent).tint(Theme.emberDeep).controlSize(.small)
                .disabled(store.isInstalling)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ember.opacity(0.12)))
    }
}

struct ConflictBanner: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.12)))
    }

    private var title: String {
        let apps = store.conflictingApps
        return apps.isEmpty ? "休眠设置被其他程序反复改回" : "\(apps.joined(separator: "、")) 在改回休眠设置"
    }

    private var detail: String {
        if store.conflictingApps.contains("UU远程") {
            return "合盖时可能因此突然休眠。请在 UU远程 设置里关闭「防止休眠」,或使用守夜时退出 UU远程。"
        }
        return "合盖时可能因此突然休眠。请关闭同类防休眠工具,或关掉它们的休眠管理功能。"
    }
}

// MARK: - Hero

struct HeroCard: View {
    @EnvironmentObject var store: Store

    private var isOn: Bool {
        if case .active = store.status { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isOn ? AnyShapeStyle(Theme.ember.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
                    .frame(width: 44, height: 44)
                    .shadow(color: isOn ? Theme.ember.opacity(0.55) : .clear, radius: 10)
                Image(systemName: isOn ? "moon.stars.fill" : "moon.zzz.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isOn ? .white : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("合盖后继续运行")
                    .font(.system(size: 14, weight: .semibold))
                statusLine
            }

            Spacer(minLength: 0)

            if store.daemonInstalled {
                Toggle("", isOn: Binding(get: { store.config.enabled },
                                         set: { store.setEnabled($0) }))
                    .toggleStyle(.switch)
                    .tint(Theme.emberDeep)
                    .labelsHidden()
            } else {
                Button {
                    store.installDaemon()
                } label: {
                    if store.isInstalling {
                        ProgressView().controlSize(.small).frame(width: 64)
                    } else {
                        Text("一键安装").font(.system(size: 12, weight: .semibold)).frame(width: 64)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.emberDeep)
                .disabled(store.isInstalling)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius + 2, style: .continuous)
                .fill(isOn
                      ? AnyShapeStyle(LinearGradient(colors: [Theme.ember.opacity(0.22), Theme.emberDeep.opacity(0.08)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color.primary.opacity(0.045)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius + 2, style: .continuous)
                .strokeBorder(isOn ? Theme.ember.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .animation(.smooth(duration: 0.35), value: isOn)
    }

    @ViewBuilder private var statusLine: some View {
        switch store.status {
        case .notInstalled:
            if let err = store.installError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.red).lineLimit(2)
            } else {
                Text("首次使用需安装后台服务,约 3 秒")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .off:
            Text("已关闭 · 合盖会正常休眠").font(.system(size: 11)).foregroundStyle(.secondary)
        case .waiting:
            Text("正在生效…").font(.system(size: 11)).foregroundStyle(.secondary)
        case .paused(let why):
            Label("已暂停 · \(why)", systemImage: "pause.circle.fill")
                .font(.system(size: 11)).foregroundStyle(.orange)
        case .active:
            Text("守夜中 · " + store.activeDetail)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.emberDeep)
                .lineLimit(1)
        }
    }
}

// MARK: - Metrics

struct MetricsRow: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 8) {
            Metric(symbol: batterySymbol,
                   tint: batteryTint,
                   value: store.battery.percent.map { "\($0)%" } ?? "—",
                   caption: store.battery.isCharging ? "充电中" : "电池供电")
            Metric(symbol: "cpu",
                   tint: chipTint,
                   value: temp(store.sensors.chip),
                   caption: "芯片 · " + store.thermal.label)
            Metric(symbol: "thermometer.medium",
                   tint: batteryTempTint,
                   value: temp(store.sensors.battery),
                   caption: "电池温度")
        }
    }

    private func temp(_ t: Double?) -> String {
        t.map { String(format: "%.0f°", $0) } ?? "—"
    }

    private var batterySymbol: String {
        if store.battery.isCharging { return "battery.100percent.bolt" }
        switch store.battery.percent ?? 100 {
        case ..<15: return "battery.0percent"
        case ..<40: return "battery.25percent"
        case ..<65: return "battery.50percent"
        case ..<90: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var batteryTint: Color {
        guard let p = store.battery.percent else { return .gray }
        if store.battery.isCharging { return .green }
        return p < store.config.threshold ? .red : (p < 40 ? .orange : .green)
    }

    private var chipTint: Color {
        if store.thermal == .serious || store.thermal == .critical { return .red }
        guard let t = store.sensors.chip else { return .gray }
        let limit = Double(store.config.chipTempLimit)
        return t >= limit ? .red : (t >= limit - 15 ? .orange : .teal)
    }

    private var batteryTempTint: Color {
        guard let t = store.sensors.battery else { return .gray }
        let limit = Double(store.config.batteryTempLimit)
        return t >= limit ? .red : (t >= limit - 5 ? .orange : .teal)
    }
}

struct Metric: View {
    let symbol: String
    let tint: Color
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            Text(caption)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Keep mode

struct KeepModeCard: View {
    @EnvironmentObject var store: Store
    private let timers = [(30, "30分"), (60, "1时"), (120, "2时"), (240, "4时"), (480, "8时")]
    private let agents = [("claude", "Claude Code"), ("codex", "Codex")]

    var body: some View {
        VStack(spacing: 6) {
            SectionLabel(text: "保持到")
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: Binding(get: { store.config.keepMode },
                                              set: { store.setKeepMode($0) })) {
                    ForEach(KeepMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                switch store.config.keepMode {
                case .always:
                    Hint("一直保持唤醒,直到你手动关闭")
                case .timer:
                    Picker("", selection: Binding(get: { store.config.timerMinutes },
                                                  set: { store.setTimerMinutes($0) })) {
                        ForEach(timers, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                case .tasks:
                    HStack(spacing: 6) {
                        ForEach(agents, id: \.0) { id, name in
                            Chip(title: name, selected: store.config.watchProcesses.contains(id)) {
                                store.toggleWatched(id)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    HStack {
                        Hint("AI 空闲超过")
                        Stepper("\(store.config.idleGraceMinutes) 分钟后休眠",
                                value: $store.config.idleGraceMinutes, in: 1...30)
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .controlSize(.small)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text(title).font(.system(size: 11.5, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(selected ? Theme.ember.opacity(0.18) : Color.primary.opacity(0.06)))
            .overlay(Capsule().strokeBorder(selected ? Theme.ember.opacity(0.5) : .clear, lineWidth: 1))
            .foregroundStyle(selected ? Theme.emberDeep : .secondary)
        }
        .buttonStyle(.plain)
    }
}

struct Hint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
    }
}

// MARK: - Safety

struct SafetyCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 6) {
            SectionLabel(text: "安全保护")
            VStack(spacing: 0) {
                Row(symbol: "battery.25percent", tint: .red,
                    title: "低电量自动休眠",
                    subtitle: "未接电源且低于 \(store.config.threshold)% 时") {
                    EmptyView()
                }
                HStack(spacing: 8) {
                    Text("5%").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Slider(value: Binding(get: { Double(store.config.threshold) },
                                          set: { store.config.threshold = Int($0) }),
                           in: 5...50, step: 5)
                        .tint(Theme.emberDeep)
                        .controlSize(.small)
                    Text("50%").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                .padding(.leading, 36)
                .padding(.bottom, 4)

                Divider().padding(.leading, 36).padding(.vertical, 6)

                Row(symbol: "thermometer.high", tint: .orange,
                    title: "过热自动休眠",
                    subtitle: store.config.pauseWhenHot ? "持续超标约 1 分钟才暂停,降温后自动恢复" : "已关闭,不建议") {
                    Toggle("", isOn: $store.config.pauseWhenHot)
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
                if store.config.pauseWhenHot {
                    VStack(spacing: 4) {
                        LimitRow(label: "电池温度超过", value: $store.config.batteryTempLimit, range: 38...50)
                        LimitRow(label: "芯片温度超过", value: $store.config.chipTempLimit, range: 85...105)
                        Text("系统开始降频时也会暂停")
                            .font(.system(size: 10.5)).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 36)
                    .padding(.top, 4)
                }

                Divider().padding(.leading, 36).padding(.vertical, 6)

                Row(symbol: "powerplug.fill", tint: .green,
                    title: "仅在充电时生效",
                    subtitle: "拔掉电源立即恢复休眠") {
                    Toggle("", isOn: $store.config.onlyWhileCharging)
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
            }
            .card()
        }
    }
}

struct LimitRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Stepper("\(value)°C", value: $value, in: range)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .controlSize(.small)
        }
    }
}

// MARK: - Automation

struct AutomationCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 6) {
            SectionLabel(text: "更多")
            VStack(spacing: 0) {
                Row(symbol: "laptopcomputer", tint: .indigo,
                    title: "合盖后熄灭屏幕",
                    subtitle: "省电,也避免屏幕在盖子里发热") {
                    Toggle("", isOn: $store.config.displayOffOnLidClose)
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
                Divider().padding(.leading, 36).padding(.vertical, 6)
                Row(symbol: "bolt.fill", tint: .yellow,
                    title: "接通电源时自动开启",
                    subtitle: "插上电就守夜,拔掉就恢复") {
                    Toggle("", isOn: $store.config.autoEnableOnCharge)
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
                Divider().padding(.leading, 36).padding(.vertical, 6)
                Row(symbol: "bell.badge.fill", tint: .red,
                    title: "暂停和完成时通知我",
                    subtitle: nil) {
                    Toggle("", isOn: $store.config.notify)
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
                Divider().padding(.leading, 36).padding(.vertical, 6)
                Row(symbol: "power", tint: .gray,
                    title: "登录时打开",
                    subtitle: nil) {
                    Toggle("", isOn: Binding(get: { store.launchAtLogin },
                                             set: { store.setLaunchAtLogin($0) }))
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
            }
            .card()
        }
    }
}

struct Row<Trailing: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            SymbolBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
    }
}
