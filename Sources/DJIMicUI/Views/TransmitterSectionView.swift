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
                Picker("", selection: voiceToneBinding) {
                    ForEach(VoiceTone.allCases, id: \.self) { tone in
                        Text(voiceToneLabel(tone)).tag(tone)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
                .accessibilityLabel(L10n.s("tx.voiceTone"))
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

/// Compact action chip for "Find". Gives the action a clear surface, a hover
/// state, a press animation, and a pulsing beacon while the LED is blinking.
private struct FindTransmitterButton: View {
    let isFinding: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var isActive: Bool { isFinding }

    private var foreground: Color {
        if isActive { return .orange }
        return isEnabled ? .primary : .secondary
    }

    private var fill: Color {
        if isActive { return .orange.opacity(0.14) }
        return .secondary.opacity(isHovering && isEnabled ? 0.18 : 0.10)
    }

    private var stroke: Color {
        if isActive { return .orange.opacity(0.35) }
        return .secondary.opacity(isHovering && isEnabled ? 0.32 : 0.18)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isActive ? "light.beacon.max.fill" : "light.beacon.max")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.orange : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: isActive && !reduceMotion)

                Text(isActive ? L10n.s("tx.find.finding") : L10n.s("tx.find"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
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
        .opacity(isEnabled || isActive ? 1 : 0.5)
        .disabled(!isEnabled)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isActive)
        .accessibilityLabel(L10n.s("tx.find"))
        .accessibilityValue(isActive ? L10n.s("tx.find.finding") : L10n.s("tx.find"))
        .help(L10n.s("tx.find.hint"))
    }
}

