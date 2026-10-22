import DJIMicProtocol
import Foundation
import SwiftUI

struct TransmitterSectionView: View {
    let model: AppModel
    let transmitter: TransmitterState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEditable: Bool {
        model.snapshot.connection.isConnected
    }

    private var isFinding: Bool {
        model.findingUnit == transmitter.unit
    }

    private var profile: DeviceProfile? {
        model.systemProfile.transmitters[transmitter.unit]
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
            detail: transmitterName,
            headerTrailing: supportsMute || supportsRecording
                ? AnyView(headerActions)
                : nil
        ) {
            SettingRow(
                title: L10n.s("tx.inputLevel"),
                systemImage: "waveform"
            ) {
                LevelMeter(level: transmitter.inputLevel)
                    .frame(width: 210)
            }

            if supportsVoiceTone {
                SettingRow(
                    title: L10n.s("tx.voiceTone"),
                    systemImage: "waveform.path"
                ) {
                    SegmentedChipSelector(
                        selection: voiceToneBinding,
                        values: VoiceTone.allCases,
                        isEnabled: isEditable,
                        label: voiceToneLabel
                    )
                }
                .disabled(!isEditable)
            }

            if supportsRecording {
                SettingRow(
                    title: L10n.s("tx.recording"),
                    systemImage: "record.circle"
                ) {
                    HStack(spacing: Spacing.xs) {
                        if transmitter.isRecording {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                Text(L10n.s("tx.rec"))
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.red)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }

                        if let time = recordingTimeText {
                            Text(time)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    .animation(
                        reduceMotion ? nil : .snappy(duration: 0.25),
                        value: transmitter.isRecording
                    )
                }
            }

            Divider()
                .padding(.vertical, Spacing.xxs)

            HStack(alignment: .center, spacing: Spacing.xs) {
                BatteryView(transmitter: transmitter, showsLabel: true)
                Spacer(minLength: 0)
                findButton
            }
            .frame(minHeight: 30)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            if supportsMute {
                muteButton
            }

            if supportsRecording {
                recordButton
            }
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
            pulsesWhenActive: true,
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
    var pulsesWhenActive = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? activeTint : (isHovering ? Color.primary : Color.secondary))
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: pulsesWhenActive && isActive && !reduceMotion
                )
                .scaleEffect(isHovering && !reduceMotion ? 1.06 : 1)
                .glassCircle(
                    size: 36,
                    tint: isActive ? activeTint.opacity(0.55) : nil
                )
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

    private let chipWidth: CGFloat = 112
    private let chipHeight: CGFloat = 32

    var body: some View {
        Button(action: action) {
            ZStack {
                label(L10n.s("tx.find"), active: false)
                    .opacity(isFinding ? 0 : 1)

                label(L10n.s("tx.find.finding"), active: true)
                    .opacity(isFinding ? 1 : 0)
            }
            .frame(width: chipWidth, height: chipHeight)
            .glassCapsule(tint: isFinding ? .orange.opacity(0.55) : nil)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableChipButtonStyle(reduceMotion: reduceMotion))
        .opacity(isEnabled || isFinding ? 1 : 0.5)
        .disabled(!isEnabled)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isFinding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.s("tx.find"))
        .accessibilityValue(isFinding ? L10n.s("tx.find.finding") : L10n.s("tx.find"))
        .help(L10n.s("tx.find.hint"))
    }

    private func label(_ title: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "light.beacon.max")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Color.orange : Color.secondary)
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: active && isFinding && !reduceMotion
                )

            Text(title)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(active ? Color.orange : (isEnabled ? Color.primary : Color.secondary))
                .lineLimit(1)
        }
    }
}
