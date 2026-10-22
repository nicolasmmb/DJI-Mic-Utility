import DJIMicProtocol
import SwiftUI

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

/// Maps the device's 7-level battery gauge to SF Symbols and copy.
/// The gauge is not a percentage.
private struct BatteryPresentation {
    let symbol: String
    let label: String
    let isLow: Bool

    static func make(for gauge: Int?) -> BatteryPresentation {
        guard let gauge else {
            return BatteryPresentation(
                symbol: "battery.0",
                label: L10n.s("battery.unknown"),
                isLow: false
            )
        }

        switch gauge {
        case 1:
            return BatteryPresentation(
                symbol: "battery.100",
                label: L10n.s("battery.full"),
                isLow: false
            )
        case 2, 3:
            return BatteryPresentation(
                symbol: "battery.75",
                label: L10n.s("battery.good"),
                isLow: false
            )
        case 4, 5:
            return BatteryPresentation(
                symbol: "battery.50",
                label: L10n.s("battery.medium"),
                isLow: false
            )
        case 6:
            return BatteryPresentation(
                symbol: "battery.25",
                label: L10n.s("battery.low"),
                isLow: true
            )
        default:
            return BatteryPresentation(
                symbol: "battery.0",
                label: L10n.s("battery.empty"),
                isLow: gauge >= 7
            )
        }
    }
}

struct BatteryView: View {
    let transmitter: TransmitterState?
    /// Adds a small "Battery" caption above the value, for card footers where
    /// the icon alone would be ambiguous.
    var showsLabel = false

    private var presentation: BatteryPresentation {
        BatteryPresentation.make(for: transmitter?.batteryGauge)
    }

    var body: some View {
        let presentation = presentation

        VStack(alignment: .leading, spacing: 1) {
            if showsLabel {
                Text(L10n.s("tx.battery"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: Spacing.xxs) {
                Image(systemName: presentation.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(presentation.isLow ? .orange : .primary)
                    .contentTransition(.symbolEffect(.replace))

                if transmitter?.charging == true {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green)
                }

                Text(presentation.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("accessibility.battery", presentation.label))
        .accessibilityValue(presentation.label)
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
