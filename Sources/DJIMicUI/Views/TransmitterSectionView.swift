import DJIMicProtocol
import Foundation
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

    private var profile: DeviceProfile? {
        model.snapshot.systemProfile.transmitters[transmitter.unit]
    }

    private var supportsVoiceTone: Bool {
        profile?.capabilities.supports(.voiceTone) ?? true
    }

    private var supportsMute: Bool {
        profile?.capabilities.supports(.mute) ?? false
    }

    private var supportsRecording: Bool {
        profile?.capabilities.supports(.recording) ?? false
    }

    private var voiceToneBinding: Binding<VoiceTone> {
        model.settingBinding(
            get: { transmitter.voiceTone },
            setting: { .voiceTone($0, unit: transmitter.unit) }
        )
    }

    private var transmitterName: String? {
        model.snapshot.transmitterDisplayName(unit: transmitter.unit)
    }

    var body: some View {
        SettingsSection(
            title: L10n.format("tx.title", transmitter.unit),
            detail: transmitterName
        ) {
            if supportsVoiceTone {
                SettingRow(title: L10n.s("tx.voiceTone")) {
                    SegmentedChipSelector(
                        selection: voiceToneBinding,
                        values: VoiceTone.allCases,
                        isEnabled: isEditable,
                        label: voiceToneLabel
                    )
                }
                .disabled(!isEditable)
            }

            SettingRow(title: L10n.s("tx.inputLevel")) {
                LevelMeter(level: transmitter.inputLevel)
                    .frame(width: 210)
            }

            if supportsRecording {
                SettingRow(title: L10n.s("tx.recording")) {
                    HStack(spacing: Spacing.xs) {
                        recordButton

                        if let time = recordingTimeText {
                            Text(time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Divider()
                .padding(.vertical, Spacing.xxs)

            HStack(alignment: .center, spacing: Spacing.xs) {
                BatteryView(transmitter: transmitter, showsLabel: true)
                Spacer(minLength: 0)

                if supportsMute {
                    muteButton
                }

                findButton
            }
            .frame(minHeight: 30)
        }
    }

    private var muteButton: some View {
        TXActionButton(
            systemImage: transmitter.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            title: transmitter.isMuted ? L10n.s("tx.mute.on") : L10n.s("tx.mute"),
            isActive: transmitter.isMuted,
            activeTint: .orange,
            isEnabled: isEditable,
            action: {
                model.send(.mute(!transmitter.isMuted, unit: transmitter.unit))
            }
        )
    }

    private var recordButton: some View {
        TXActionButton(
            systemImage: transmitter.isRecording ? "stop.circle.fill" : "record.circle",
            title: transmitter.isRecording ? L10n.s("tx.rec.stop") : L10n.s("tx.rec"),
            isActive: transmitter.isRecording,
            activeTint: .red,
            isEnabled: isEditable,
            action: {
                model.send(.recording(!transmitter.isRecording, unit: transmitter.unit))
            }
        )
    }

    private var recordingTimeText: String? {
        guard let total = transmitter.recordingTimeTotal,
              let remaining = transmitter.recordingTimeRemaining else {
            return nil
        }
        return String(format: "%.1fh / %.1fh", total, remaining)
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

/// Compact round action used for mute and REC on a transmitter card.
private struct TXActionButton: View {
    let systemImage: String
    let title: String
    let isActive: Bool
    let activeTint: Color
    var isEnabled = true
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var fill: Color {
        if isActive { return activeTint.opacity(0.14) }
        return .secondary.opacity(isHovering && isEnabled ? 0.18 : 0.10)
    }

    private var stroke: Color {
        if isActive { return activeTint.opacity(0.35) }
        return .secondary.opacity(isHovering && isEnabled ? 0.32 : 0.18)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? activeTint : (isHovering ? Color.primary : Color.secondary))
                .frame(width: 26, height: 26)
                .background(fill, in: Circle())
                .overlay(Circle().strokeBorder(stroke, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressableChipButtonStyle(reduceMotion: reduceMotion))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
        .help(title)
        .accessibilityLabel(title)
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
