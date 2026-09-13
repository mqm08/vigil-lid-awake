import SwiftUI

struct PanelView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 12) {
            header
            HeroCard()
            if store.hasConflict { ConflictBanner() }
            if store.daemonOutdated { UpdateBanner() }
            MetricsRow()
            DurationCard()
            SafetyCard()
            AutomationCard()
            footer
        }
        .padding(14)
        .frame(width: 344)
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
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("有其他程序在修改休眠设置")
                    .font(.system(size: 12, weight: .semibold))
                Text("请关闭 Amphetamine、Lidless 等同类工具,否则守夜会时断时续。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.12)))
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
            if let r = store.remaining {
                Text("守夜中 · 剩余 \(r)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.emberDeep)
            } else {
                Text("守夜中 · 合盖不会休眠")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.emberDeep)
            }
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
                   caption: store.battery.isCharging ? "充电中" : "电池")
            Metric(symbol: "thermometer.medium",
                   tint: tempTint,
                   value: store.temperature.map { String(format: "%.0f°", $0) } ?? "—",
                   caption: store.thermal.label)
            Metric(symbol: store.battery.isCharging ? "powerplug.fill" : "powerplug",
                   tint: store.battery.isCharging ? .green : .gray,
                   value: store.battery.isCharging ? "已接" : "未接",
                   caption: "电源")
        }
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

    private var tempTint: Color {
        switch store.thermal {
        case .serious, .critical: return .red
        case .fair: return .orange
        default:
            guard let t = store.temperature else { return .gray }
            return t > Double(store.config.tempLimit) ? .red : .teal
        }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Duration

struct DurationCard: View {
    @EnvironmentObject var store: Store
    private let options: [(String, Int?)] = [("不限", nil), ("30分", 30), ("1时", 60), ("2时", 120), ("4时", 240)]

    var body: some View {
        VStack(spacing: 6) {
            SectionLabel(text: "保持时长")
            Picker("", selection: Binding(get: { store.config.durationMinutes ?? -1 },
                                          set: { store.setDuration($0 == -1 ? nil : $0) })) {
                ForEach(options, id: \.0) { label, minutes in
                    Text(label).tag(minutes ?? -1)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
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
                    title: "低电量自动关闭",
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
                    title: "过热自动暂停",
                    subtitle: store.config.pauseWhenHot ? "超过 \(store.config.tempLimit)°C 或系统过热时" : "已关闭") {
                    Toggle("", isOn: $store.config.pauseWhenHot)
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
                if store.config.pauseWhenHot {
                    HStack {
                        Text("温度上限").font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Stepper("\(store.config.tempLimit)°C", value: $store.config.tempLimit, in: 40...75)
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .controlSize(.small)
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

// MARK: - Automation

struct AutomationCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 6) {
            SectionLabel(text: "自动化")
            VStack(spacing: 0) {
                Row(symbol: "bolt.fill", tint: .yellow,
                    title: "接通电源时自动开启",
                    subtitle: "插上电就守夜,拔掉就恢复") {
                    Toggle("", isOn: $store.config.autoEnableOnCharge)
                        .toggleStyle(.switch).controlSize(.mini).tint(Theme.emberDeep).labelsHidden()
                }
                Divider().padding(.leading, 36).padding(.vertical, 6)
                Row(symbol: "power", tint: .indigo,
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
