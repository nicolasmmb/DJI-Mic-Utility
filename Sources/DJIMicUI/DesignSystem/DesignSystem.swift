import DJIMicProtocol
import SwiftUI

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

enum PanelMetrics {
    static let width: CGFloat = 380
    static let height: CGFloat = 540
    static let contentInset: CGFloat = 16
    static let cardRadius: CGFloat = 10
    static let footerHeight: CGFloat = 40
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String?
    @ViewBuilder var content: Content

    init(
        title: String,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.action = action
        self.actionTitle = actionTitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                SectionHeader(title: title)
                Spacer(minLength: 0)
                if let action, let actionTitle {
                    Button(action: action) {
                        HStack(spacing: 2) {
                            Text(actionTitle)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(actionTitle)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: PanelMetrics.cardRadius, style: .continuous))
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            content
        }
        .frame(minHeight: 26)
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.s("nav.back"))
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
            .padding(.trailing, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(L10n.s("nav.back"))
    }
}

struct StatusBadge: View {
    let connection: ConnectionState

    private var label: String {
        switch connection {
        case .connected: L10n.s("status.connected")
        case .connecting: L10n.s("status.connecting")
        case .reconnecting: L10n.s("status.reconnecting")
        case .disconnected: L10n.s("status.disconnected")
        case .failed: L10n.s("status.failed")
        }
    }

    private var color: Color {
        switch connection {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        case .disconnected: .gray
        case .failed: .red
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("accessibility.connection", label))
    }
}

struct BatteryView: View {
    let transmitter: TransmitterState?

    private var symbol: String {
        guard let gauge = transmitter?.batteryGauge else { return "battery.0" }
        switch gauge {
        case 1: return "battery.100"
        case 2, 3: return "battery.75"
        case 4, 5: return "battery.50"
        case 6: return "battery.25"
        default: return "battery.0"
        }
    }

    private var label: String {
        guard let gauge = transmitter?.batteryGauge else { return L10n.s("battery.unknown") }
        switch gauge {
        case 1: return L10n.s("battery.full")
        case 2, 3: return L10n.s("battery.good")
        case 4, 5: return L10n.s("battery.medium")
        case 6: return L10n.s("battery.low")
        default: return L10n.s("battery.empty")
        }
    }

    private var isLow: Bool {
        (transmitter?.batteryGauge ?? 0) >= 6
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isLow ? .orange : .primary)
                .contentTransition(.symbolEffect(.replace))
            if transmitter?.charging == true {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("accessibility.battery", label))
        .accessibilityValue(label)
    }
}

struct LevelMeter: View {
    let level: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var value: Double {
        Double(min(max(level ?? 0, 0), 100))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(proxy.size.width * value / 100, value > 0 ? 3 : 0))
                    .clipShape(Capsule())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: value)
            }
        }
        .frame(height: 6)
        .accessibilityLabel(L10n.s("tx.inputLevel"))
        .accessibilityValue(L10n.format("accessibility.level", Int(value)))
    }
}

struct InlineErrorView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.orange.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct PanelFooter: View {
    let onDiagnostics: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onDiagnostics) {
                Label(L10n.s("menu.diagnostics"), systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            Spacer(minLength: 0)

            Button(action: onQuit) {
                Label(L10n.s("menu.quit"), systemImage: "power")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, PanelMetrics.contentInset)
        .frame(height: PanelMetrics.footerHeight)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
