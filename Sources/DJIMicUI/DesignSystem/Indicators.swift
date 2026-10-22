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

/// Read-only value shown as a chip, matching the surface language of the
/// panel's action chips. Used for locked settings and compact readouts.
struct ValueChip: View {
    let value: String
    var systemImage: String?
    var animatesDigits = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, value: value)
            }

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(animatesDigits ? .numericText() : .opacity)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(.secondary.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(.secondary.opacity(0.18), lineWidth: 1))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: value)
    }
}

/// Read-only value that the hardware controls itself, such as noise
/// reduction.
struct LockedValueBadge: View {
    let value: String

    var body: some View {
        ValueChip(value: value, systemImage: "lock.fill")
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

/// Input level meter. The gradient is anchored to the full track and masked by
/// the current value, so colors do not shift when the level changes. A peak
/// marker holds recent transients and decays back to the live level.
struct LevelMeter: View {
    let level: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var peak: Double = 0
    @State private var liveValue: Double = 0
    @State private var lastPeakAt = Date.distantPast

    private var value: Double {
        Double(min(max(level ?? 0, 0), 100))
    }

    private var gradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .green, location: 0),
                .init(color: .green, location: 0.55),
                .init(color: .yellow, location: 0.78),
                .init(color: .orange, location: 0.92),
                .init(color: .red, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = max(width * value / 100, value > 0 ? 4 : 0)
            let peakX = min(max(width * peak / 100 - 1, 0), max(width - 2, 0))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.14))
                    .frame(height: 8)

                Capsule()
                    .fill(gradient)
                    .frame(height: 8)
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: fillWidth)
                    }
                    .shadow(
                        color: .orange.opacity(value >= 85 ? 0.45 : 0),
                        radius: 3
                    )

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(.primary.opacity(0.9))
                    .frame(width: 2, height: 13)
                    .shadow(color: .black.opacity(0.18), radius: 1)
                    .offset(x: peakX)
                    .opacity(peak > value + 0.5 ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 14)
        .animation(reduceMotion ? nil : .linear(duration: 0.1), value: value)
        .animation(reduceMotion ? nil : .linear(duration: 0.15), value: peak)
        .onAppear {
            liveValue = value
            peak = value
        }
        .onChange(of: value) { _, newValue in
            liveValue = newValue
            if newValue >= peak {
                peak = newValue
                lastPeakAt = Date()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard Date().timeIntervalSince(lastPeakAt) > 0.8 else { continue }
                let next = max(liveValue, peak - 1.5)
                if next != peak {
                    peak = next
                }
            }
        }
        .accessibilityLabel(L10n.s("tx.inputLevel"))
        .accessibilityValue(L10n.format("accessibility.level", Int(value)))
    }
}
