import DJIMicProtocol
import SwiftUI

/// Secondary settings page. Scope is the top-level hierarchy (transmitter /
/// receiver); inside each card, settings are grouped by function.
struct MoreSettingsContent: View {
    let model: AppModel

    private var transmitter: TransmitterState? {
        model.snapshot.sortedTransmitters.first
    }

    private var receiver: ReceiverState? {
        model.snapshot.receiver
    }

    private var transmitterProfile: DeviceProfile? {
        guard let transmitter else { return nil }
        return model.snapshot.systemProfile.transmitters[transmitter.unit]
    }

    private var canEditTransmitterSettings: Bool {
        model.snapshot.connection.isConnected && transmitter != nil
    }

    private var canEditReceiverSettings: Bool {
        canEditTransmitterSettings && receiver != nil
    }

    private var canEditMicLED: Bool {
        canEditTransmitterSettings && model.findingUnit == nil
    }

    private var supportsLowCut: Bool {
        transmitterProfile?.capabilities.supports(.lowCut) ?? true
    }

    private var supportsClipping: Bool {
        model.snapshot.systemProfile.receiver.capabilities.supports(.clippingControl)
    }

    private var supportsMicLED: Bool {
        transmitterProfile?.capabilities.supports(.micLED) ?? true
    }

    private var supportsAutoOff: Bool {
        transmitterProfile?.capabilities.supports(.autoOffTX) ?? true
    }

    private func sharedCapability(_ key: SettingID) -> DeviceProfile? {
        model.snapshot.systemProfile.sharedTransmitterCapability(for: key)
    }

    private var supportsVibration: Bool {
        sharedCapability(.vibration) != nil
    }

    private var supportsFloat32: Bool {
        sharedCapability(.float32Recording) != nil
    }

    private var supportsStartupRecording: Bool {
        sharedCapability(.startupAutoRecording) != nil
    }

    private var supportsRecStopLock: Bool {
        sharedCapability(.recStopLock) != nil
    }

    private var hasAudioGroup: Bool { supportsLowCut }
    private var hasRecordingGroup: Bool { supportsFloat32 || supportsStartupRecording }
    private var hasButtonsGroup: Bool { supportsVibration || supportsRecStopLock || supportsMicLED }
    private var hasGeneralGroup: Bool { supportsAutoOff }

    private var lowCutBinding: Binding<Bool> {
        model.settingBinding(
            get: { transmitter?.lowCut ?? false },
            setting: { .lowCut($0) }
        )
    }

    private var clippingBinding: Binding<Bool> {
        model.settingBinding(
            get: { receiver?.clippingControl ?? false },
            setting: { .clippingControl($0) }
        )
    }

    private var micLEDBinding: Binding<Bool> {
        model.settingBinding(
            get: { !(transmitter?.ledsOff ?? true) },
            setting: { .micLED($0, unit: nil) }
        )
    }

    private var autoOffBinding: Binding<Bool> {
        model.settingBinding(
            get: { transmitter?.autoOff ?? false },
            setting: { .autoOffTX($0) }
        )
    }

    private var vibrationBinding: Binding<Bool> {
        model.settingBinding(
            get: { transmitter?.vibrationEnabled ?? false },
            setting: { .vibration($0) }
        )
    }

    private var float32Binding: Binding<Bool> {
        model.settingBinding(
            get: { transmitter?.float32Recording ?? false },
            setting: { .float32Recording($0) }
        )
    }

    private var startupRecordingBinding: Binding<Bool> {
        model.settingBinding(
            get: { transmitter?.startupAutoRecording ?? false },
            setting: { .startupAutoRecording($0) }
        )
    }

    private var recStopLockBinding: Binding<Bool> {
        model.settingBinding(
            get: { transmitter?.recStopLock ?? false },
            setting: { .recStopLock($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            transmitterSection

            if supportsClipping {
                receiverSection
            }

            if !canEditTransmitterSettings {
                disconnectedHint
            }
        }
    }

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
            isEnabled: canEditTransmitterSettings
        )
    }

    @ViewBuilder
    private var recordingRows: some View {
        if supportsFloat32 {
            ToggleSettingRow(
                title: L10n.s("more.float32"),
                subtitle: L10n.s("more.float32Note"),
                systemImage: "waveform",
                info: L10n.s("more.float32.info"),
                isOn: float32Binding,
                isEnabled: canEditTransmitterSettings
            )
        }

        if supportsFloat32 && supportsStartupRecording {
            Divider()
        }

        if supportsStartupRecording {
            ToggleSettingRow(
                title: L10n.s("more.startupRecording"),
                subtitle: L10n.s("more.startupRecordingNote"),
                systemImage: "play.circle",
                info: L10n.s("more.startupRecording.info"),
                isOn: startupRecordingBinding,
                isEnabled: canEditTransmitterSettings
            )
        }
    }

    @ViewBuilder
    private var buttonsRows: some View {
        if supportsVibration {
            ToggleSettingRow(
                title: L10n.s("more.vibration"),
                subtitle: L10n.s("more.vibrationNote"),
                systemImage: "iphone.radiowaves.left.and.right",
                info: L10n.s("more.vibration.info"),
                isOn: vibrationBinding,
                isEnabled: canEditTransmitterSettings
            )
        }

        if supportsVibration && supportsRecStopLock {
            Divider()
        }

        if supportsRecStopLock {
            ToggleSettingRow(
                title: L10n.s("more.recStopLock"),
                subtitle: L10n.s("more.recStopLockNote"),
                systemImage: "lock.circle",
                info: L10n.s("more.recStopLock.info"),
                isOn: recStopLockBinding,
                isEnabled: canEditTransmitterSettings
            )
        }

        if (supportsVibration || supportsRecStopLock) && supportsMicLED {
            Divider()
        }

        if supportsMicLED {
            ToggleSettingRow(
                title: L10n.s("more.micLED"),
                subtitle: L10n.s("more.micLEDNote"),
                systemImage: "light.max",
                info: L10n.s("more.micLED.info"),
                isOn: micLEDBinding,
                isEnabled: canEditMicLED
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
            isEnabled: canEditTransmitterSettings
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
                isEnabled: canEditReceiverSettings
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
