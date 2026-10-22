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

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: title)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                content
            }
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
                .frame(maxWidth: .infinity, alignment: .leading)
            content
        }
        .frame(minHeight: 28)
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
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
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

    private var tint: Color {
        guard let gauge = transmitter?.batteryGauge else { return .gray }
        return gauge >= 6 ? .orange : .gray
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            if transmitter?.charging == true {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("accessibility.battery", label))
        .accessibilityValue(label)
    }
}

struct LevelMeter: View {
    let level: Int?

    private var value: Double {
        Double(min(max(level ?? 0, 0), 100))
    }

    private var tint: Color {
        if value >= 88 { return .red }
        if value >= 70 { return .orange }
        return .green
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * value / 100)
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
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
