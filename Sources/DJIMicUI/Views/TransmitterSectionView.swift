import DJIMicProtocol
import SwiftUI

struct TransmitterSectionView: View {
    let model: AppModel
    let transmitter: TransmitterState

    private var isEditable: Bool {
        model.snapshot.connection.isConnected
    }

    private var isFinding: Bool {
        model.findingUnit == transmitter.unit
    }

    private var voiceToneBinding: Binding<VoiceTone> {
        model.settingBinding(
            get: { transmitter.voiceTone },
            setting: { .voiceTone($0, unit: transmitter.unit) }
        )
    }

    private var transmitterName: String? {
        model.snapshot.transmitterIdentities[transmitter.unit]?.productName
    }

    var body: some View {
        SettingsSection(
            title: L10n.format("tx.title", transmitter.unit),
            detail: transmitterName
        ) {
            SettingRow(title: L10n.s("tx.voiceTone")) {
                SegmentedChipSelector(
                    selection: voiceToneBinding,
                    values: VoiceTone.allCases,
                    isEnabled: isEditable,
                    label: voiceToneLabel
                )
            }
            .disabled(!isEditable)

            SettingRow(title: L10n.s("tx.inputLevel")) {
                LevelMeter(level: transmitter.inputLevel)
                    .frame(width: 170)
            }

            Divider()
                .padding(.vertical, Spacing.xxs)

            HStack(alignment: .center, spacing: Spacing.sm) {
                BatteryView(transmitter: transmitter, showsLabel: true)
                Spacer(minLength: 0)
                findButton
            }
            .frame(minHeight: 30)
        }
    }

    private var findButton: some View {
        FindTransmitterButton(
            isFinding: isFinding,
            isEnabled: isEditable && model.findingUnit == nil,
            action: { model.findTransmitter(unit: transmitter.unit) }
        )
    }

    private func voiceToneLabel(_ tone: VoiceTone) -> String {
        switch tone {
        case .regular: L10n.s("tx.voiceTone.regular")
        case .rich: L10n.s("tx.voiceTone.rich")
        case .bright: L10n.s("tx.voiceTone.bright")
        }
    }
}

/// Compact action chip for "Find". Fixed geometry and a plain crossfade keep
/// the state change calm: nothing resizes, nothing bounces, only the color and
/// the two labels fade into each other while the beacon pulses.
private struct FindTransmitterButton: View {
    let isFinding: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private let chipWidth: CGFloat = 100
    private let chipHeight: CGFloat = 26

    private var fill: Color {
        if isFinding { return .orange.opacity(0.14) }
        return .secondary.opacity(isHovering && isEnabled ? 0.18 : 0.10)
    }

    private var stroke: Color {
        if isFinding { return .orange.opacity(0.35) }
        return .secondary.opacity(isHovering && isEnabled ? 0.32 : 0.18)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                label(L10n.s("tx.find"), active: false)
                    .opacity(isFinding ? 0 : 1)

                label(L10n.s("tx.find.finding"), active: true)
                    .opacity(isFinding ? 1 : 0)
            }
            .frame(width: chipWidth, height: chipHeight)
            .background(fill, in: Capsule())
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableChipButtonStyle(reduceMotion: reduceMotion))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .opacity(isEnabled || isFinding ? 1 : 0.5)
        .disabled(!isEnabled)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isFinding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.s("tx.find"))
        .accessibilityValue(isFinding ? L10n.s("tx.find.finding") : L10n.s("tx.find"))
        .help(L10n.s("tx.find.hint"))
    }

    private func label(_ title: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "light.beacon.max")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? Color.orange : Color.secondary)
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: active && isFinding && !reduceMotion
                )

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? Color.orange : (isEnabled ? Color.primary : Color.secondary))
                .lineLimit(1)
        }
    }
}
