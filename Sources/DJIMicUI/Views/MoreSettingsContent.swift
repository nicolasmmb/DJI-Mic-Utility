import DJIMicProtocol
import SwiftUI

/// Stable projection of the settings that the secondary page renders. Live
/// input levels and battery changes arrive at ~10 Hz and must not rebuild the
/// glass cards.
struct MoreSettingsState: Equatable {
    var connected: Bool
    var unit: Int?
    var canEditTransmitter: Bool
    var canEditReceiver: Bool
    var canEditMicLED: Bool
    var lowCut: Bool
    var clipping: Bool
    var ledsOff: Bool
    var autoOff: Bool
    var vibration: Bool
    var float32: Bool
    var startup: Bool
    var recStopLock: Bool
    var supportsLowCut: Bool
    var supportsClipping: Bool
    var supportsMicLED: Bool
    var supportsAutoOff: Bool
    var supportsVibration: Bool
    var supportsFloat32: Bool
    var supportsStartup: Bool
    var supportsRecStopLock: Bool
}

/// Secondary settings page. Scope is the top-level hierarchy (transmitter /
/// receiver); inside each card, settings are grouped by function.
struct MoreSettingsContent: View {
    let model: AppModel

    private var state: MoreSettingsState {
        let transmitter = model.snapshot.sortedTransmitters.first
        let receiver = model.snapshot.receiver
        let system = model.systemProfile
        let profile = transmitter.flatMap { system.transmitters[$0.unit] }
        let connected = model.snapshot.connection.isConnected
        let hasTransmitter = connected && transmitter != nil
        let hasReceiver = hasTransmitter && receiver != nil

        return MoreSettingsState(
            connected: connected,
            unit: transmitter?.unit,
            canEditTransmitter: hasTransmitter,
            canEditReceiver: hasReceiver,
            canEditMicLED: hasTransmitter && model.findingUnit == nil,
            lowCut: transmitter?.lowCut ?? false,
            clipping: receiver?.clippingControl ?? false,
            ledsOff: transmitter?.ledsOff ?? true,
            autoOff: transmitter?.autoOff ?? false,
            vibration: transmitter?.vibrationEnabled ?? false,
            float32: transmitter?.float32Recording ?? false,
            startup: transmitter?.startupAutoRecording ?? false,
            recStopLock: transmitter?.recStopLock ?? false,
            supportsLowCut: profile?.capabilities.supports(.lowCut) ?? true,
            supportsClipping: system.receiver.capabilities.supports(.clippingControl),
            supportsMicLED: profile?.capabilities.supports(.micLED) ?? true,
            supportsAutoOff: profile?.capabilities.supports(.autoOffTX) ?? true,
            supportsVibration: system.sharedTransmitterCapability(for: .vibration) != nil,
            supportsFloat32: system.sharedTransmitterCapability(for: .float32Recording) != nil,
            supportsStartup: system.sharedTransmitterCapability(for: .startupAutoRecording) != nil,
            supportsRecStopLock: system.sharedTransmitterCapability(for: .recStopLock) != nil
        )
    }

    var body: some View {
        MoreSettingsBody(model: model, state: state)
            .equatable()
    }
}

private struct MoreSettingsBody: View, Equatable {
    let model: AppModel
    let state: MoreSettingsState

    static func == (lhs: MoreSettingsBody, rhs: MoreSettingsBody) -> Bool {
        lhs.state == rhs.state
    }

    // MARK: - Bindings

    private var lowCutBinding: Binding<Bool> {
        Binding(get: { state.lowCut }, set: { model.send(.lowCut($0)) })
    }

    private var clippingBinding: Binding<Bool> {
        Binding(get: { state.clipping }, set: { model.send(.clippingControl($0)) })
    }

    private var micLEDBinding: Binding<Bool> {
        Binding(get: { !state.ledsOff }, set: { model.send(.micLED($0, unit: nil)) })
    }

    private var autoOffBinding: Binding<Bool> {
        Binding(get: { state.autoOff }, set: { model.send(.autoOffTX($0)) })
    }

    private var vibrationBinding: Binding<Bool> {
        Binding(get: { state.vibration }, set: { model.send(.vibration($0)) })
    }

    private var float32Binding: Binding<Bool> {
        Binding(get: { state.float32 }, set: { model.send(.float32Recording($0)) })
    }

    private var startupRecordingBinding: Binding<Bool> {
        Binding(get: { state.startup }, set: { model.send(.startupAutoRecording($0)) })
    }

    private var recStopLockBinding: Binding<Bool> {
        Binding(get: { state.recStopLock }, set: { model.send(.recStopLock($0)) })
    }

    // MARK: - Page

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            transmitterSection

            if state.supportsClipping {
                receiverSection
            }

            if !state.canEditTransmitter {
                disconnectedHint
            }
        }
    }

    private var hasAudioGroup: Bool { state.supportsLowCut }
    private var hasRecordingGroup: Bool { state.supportsFloat32 || state.supportsStartup }
    private var hasButtonsGroup: Bool {
        state.supportsVibration || state.supportsRecStopLock || state.supportsMicLED
    }
    private var hasGeneralGroup: Bool { state.supportsAutoOff }

    // MARK: - Transmitter

    private var transmitterSection: some View {
        SettingsSection(
            title: L10n.s("more.transmitter"),
            systemImage: "mic.fill",
            footnote: L10n.s("more.transmitterNote")
        ) {
            if hasAudioGroup {
                SettingsGroupLabel(title: L10n.s("more.audio"))
                lowCutRow
            }

            if hasRecordingGroup {
                if hasAudioGroup { Divider() }
                SettingsGroupLabel(title: L10n.s("more.recording"))
                recordingRows
            }

            if hasButtonsGroup {
                if hasAudioGroup || hasRecordingGroup { Divider() }
                SettingsGroupLabel(title: L10n.s("more.buttons"))
                buttonsRows
            }

            if hasGeneralGroup {
                if hasAudioGroup || hasRecordingGroup || hasButtonsGroup { Divider() }
                SettingsGroupLabel(title: L10n.s("more.general"))
                autoOffRow
            }
        }
    }

    private var lowCutRow: some View {
        ToggleSettingRow(
            title: L10n.s("more.lowCut"),
            subtitle: L10n.s("more.lowCutNote"),
            systemImage: "waveform.path.ecg",
            info: L10n.s("more.lowCut.info"),
            isOn: lowCutBinding,
            isEnabled: state.canEditTransmitter
        )
    }

    @ViewBuilder
    private var recordingRows: some View {
        if state.supportsFloat32 {
            ToggleSettingRow(
                title: L10n.s("more.float32"),
                subtitle: L10n.s("more.float32Note"),
                systemImage: "waveform",
                info: L10n.s("more.float32.info"),
                isOn: float32Binding,
                isEnabled: state.canEditTransmitter
            )
        }

        if state.supportsFloat32 && state.supportsStartup {
            Divider()
        }

        if state.supportsStartup {
            ToggleSettingRow(
                title: L10n.s("more.startupRecording"),
                subtitle: L10n.s("more.startupRecordingNote"),
                systemImage: "play.circle",
                info: L10n.s("more.startupRecording.info"),
                isOn: startupRecordingBinding,
                isEnabled: state.canEditTransmitter
            )
        }
    }

    @ViewBuilder
    private var buttonsRows: some View {
        if state.supportsVibration {
            ToggleSettingRow(
                title: L10n.s("more.vibration"),
                subtitle: L10n.s("more.vibrationNote"),
                systemImage: "iphone.radiowaves.left.and.right",
                info: L10n.s("more.vibration.info"),
                isOn: vibrationBinding,
                isEnabled: state.canEditTransmitter
            )
        }

        if state.supportsVibration && state.supportsRecStopLock {
            Divider()
        }

        if state.supportsRecStopLock {
            ToggleSettingRow(
                title: L10n.s("more.recStopLock"),
                subtitle: L10n.s("more.recStopLockNote"),
                systemImage: "lock.circle",
                info: L10n.s("more.recStopLock.info"),
                isOn: recStopLockBinding,
                isEnabled: state.canEditTransmitter
            )
        }

        if (state.supportsVibration || state.supportsRecStopLock) && state.supportsMicLED {
            Divider()
        }

        if state.supportsMicLED {
            ToggleSettingRow(
                title: L10n.s("more.micLED"),
                subtitle: L10n.s("more.micLEDNote"),
                systemImage: "light.max",
                info: L10n.s("more.micLED.info"),
                isOn: micLEDBinding,
                isEnabled: state.canEditMicLED
            )
        }
    }

    private var autoOffRow: some View {
        ToggleSettingRow(
            title: L10n.s("more.autoOff"),
            subtitle: L10n.s("more.autoOffNote"),
            systemImage: "moon.zzz",
            info: L10n.s("more.autoOff.info"),
            isOn: autoOffBinding,
            isEnabled: state.canEditTransmitter
        )
    }

    // MARK: - Receiver

    private var receiverSection: some View {
        SettingsSection(
            title: L10n.s("more.receiver"),
            systemImage: "dot.radiowaves.left.and.right"
        ) {
            SettingsGroupLabel(title: L10n.s("more.audio"))

            ToggleSettingRow(
                title: L10n.s("more.clipping"),
                subtitle: L10n.s("more.clippingNote"),
                systemImage: "waveform.badge.exclamationmark",
                info: L10n.s("more.clipping.info"),
                isOn: clippingBinding,
                isEnabled: state.canEditReceiver
            )
        }
    }

    private var disconnectedHint: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "cable.connector.slash")
                .font(.caption)
                .foregroundStyle(.orange)

            Text(L10n.s("tx.notConnected"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
