import DJIMicProtocol
import Foundation
import SwiftUI

/// Stable projection of a transmitter card. Input level is intentionally
/// excluded: it updates at status-push rate and is rendered by a small child
/// view so the glass card is not rebuilt while scrolling.
struct TransmitterCardState: Equatable {
    var unit: Int
    var name: String?
    var connected: Bool
    var isFinding: Bool
    var findingAny: Bool
    var isMuted: Bool
    var isRecording: Bool
    var batteryGauge: Int
    var charging: Bool
    var voiceTone: VoiceTone
    var recordingTimeTotal: Double?
    var recordingTimeRemaining: Double?
    var supportsVoiceTone: Bool
    var supportsMute: Bool
    var supportsRecording: Bool
}

struct TransmitterSectionView: View {
    let model: AppModel
    let transmitter: TransmitterState

    private var state: TransmitterCardState {
        let profile = model.systemProfile.transmitters[transmitter.unit]
        return TransmitterCardState(
            unit: transmitter.unit,
            name: model.snapshot.transmitterDisplayName(unit: transmitter.unit),
            connected: model.snapshot.connection.isConnected,
            isFinding: model.findingUnit == transmitter.unit,
            findingAny: model.findingUnit != nil,
            isMuted: transmitter.isMuted,
            isRecording: transmitter.isRecording,
            batteryGauge: transmitter.batteryGauge,
            charging: transmitter.charging,
            voiceTone: transmitter.voiceTone,
            recordingTimeTotal: transmitter.recordingTimeTotal,
            recordingTimeRemaining: transmitter.recordingTimeRemaining,
            supportsVoiceTone: profile?.capabilities.supports(.voiceTone) ?? true,
            supportsMute: profile?.capabilities.supports(.mute) ?? false,
            supportsRecording: profile?.capabilities.supports(.recording) ?? false
        )
    }

    var body: some View {
        TransmitterCardBody(model: model, state: state)
            .equatable()
    }
}

private struct TransmitterCardBody: View, Equatable {
    let model: AppModel
    let state: TransmitterCardState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func == (lhs: TransmitterCardBody, rhs: TransmitterCardBody) -> Bool {
        lhs.state == rhs.state
    }

    private var isEditable: Bool { state.connected }

    private var voiceToneBinding: Binding<VoiceTone> {
        Binding(
            get: { state.voiceTone },
            set: { model.send(.voiceTone($0, unit: state.unit)) }
        )
    }

    var body: some View {
        SettingsSection(
            title: L10n.format("tx.title", state.unit),
            detail: state.name,
            headerTrailing: state.supportsMute || state.supportsRecording
                ? AnyView(headerActions)
                : nil
        ) {
            SettingRow(
                title: L10n.s("tx.inputLevel"),
                systemImage: "waveform"
            ) {
                LiveInputLevel(model: model, unit: state.unit)
                    .frame(width: 210)
            }

            if state.supportsVoiceTone {
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

            if state.supportsRecording {
                SettingRow(
                    title: L10n.s("tx.recording"),
                    systemImage: "record.circle"
                ) {
                    HStack(spacing: Spacing.xs) {
                        if state.isRecording {
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
                        value: state.isRecording
                    )
                }
            }

            Divider()
                .padding(.vertical, Spacing.xxs)

            HStack(alignment: .center, spacing: Spacing.xs) {
                BatteryView(
                    gauge: state.batteryGauge,
                    charging: state.charging,
                    showsLabel: true
                )
                Spacer(minLength: 0)
                findButton
            }
            .frame(minHeight: 30)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            if state.supportsMute {
                muteButton
            }

            if state.supportsRecording {
                recordButton
            }
        }
    }

    private var muteButton: some View {
        TXActionButton(
            systemImage: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            title: state.isMuted ? L10n.s("tx.mute.on") : L10n.s("tx.mute"),
            isActive: state.isMuted,
            activeTint: .orange,
            isEnabled: isEditable,
            action: {
                model.send(.mute(!state.isMuted, unit: state.unit))
            }
        )
    }

    private var recordButton: some View {
        TXActionButton(
            systemImage: state.isRecording ? "stop.circle.fill" : "record.circle",
            title: state.isRecording ? L10n.s("tx.rec.stop") : L10n.s("tx.rec"),
            isActive: state.isRecording,
            activeTint: .red,
            isEnabled: isEditable,
            pulsesWhenActive: true,
            action: {
                model.send(.recording(!state.isRecording, unit: state.unit))
            }
        )
    }

    private var recordingTimeText: String? {
        guard let total = state.recordingTimeTotal,
              let remaining = state.recordingTimeRemaining else {
            return nil
        }
        return String(format: "%.1fh / %.1fh", total, remaining)
    }

    private var findButton: some View {
        FindTransmitterButton(
            isFinding: state.isFinding,
            isEnabled: isEditable && !state.findingAny,
            action: { model.findTransmitter(unit: state.unit) }
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

/// Live-only island: the parent card is Equatable and does not observe the
/// 10 Hz input level; this view updates by itself.
private struct LiveInputLevel: View {
    let model: AppModel
    let unit: Int

    var body: some View {
        LevelMeter(level: model.snapshot.transmitters[unit]?.inputLevel)
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
