import DJIMicProtocol
import SwiftUI

/// Secondary settings page, grouped by function (matching DJI's app) with a
/// compact scope badge on every row.
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

    private var supportsRecordingSection: Bool {
        supportsFloat32 || supportsStartupRecording
    }

    private var supportsButtonsSection: Bool {
        supportsVibration || supportsRecStopLock || supportsMicLED
    }

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
            audioSection

            if supportsRecordingSection {
                recordingSection
            }

            if supportsButtonsSection {
                buttonsSection
            }

            if supportsAutoOff {
                generalSection
            }

            if !canEditTransmitterSettings {
                disconnectedHint
            }
        }
    }

    // MARK: - Audio

    @ViewBuilder
    private var audioSection: some View {
        if supportsLowCut || supportsClipping {
            SettingsSection(
                title: L10n.s("more.audio"),
                systemImage: "waveform"
            ) {
                if supportsLowCut {
                    ToggleSettingRow(
                        title: L10n.s("more.lowCut"),
                        subtitle: L10n.s("more.lowCutNote"),
                        systemImage: "waveform.path.ecg",
                        badge: L10n.s("scope.tx"),
                        isOn: lowCutBinding,
                        isEnabled: canEditTransmitterSettings
                    )
                }

                if supportsLowCut && supportsClipping {
                    Divider()
                }

                if supportsClipping {
                    ToggleSettingRow(
                        title: L10n.s("more.clipping"),
                        subtitle: L10n.s("more.clippingNote"),
                        systemImage: "waveform.badge.exclamationmark",
                        badge: L10n.s("scope.rxTx"),
                        isOn: clippingBinding,
                        isEnabled: canEditReceiverSettings
                    )
                }
            }
        }
    }

    // MARK: - Recording

    private var recordingSection: some View {
        SettingsSection(
            title: L10n.s("more.recording"),
            systemImage: "record.circle"
        ) {
            if supportsFloat32 {
                ToggleSettingRow(
                    title: L10n.s("more.float32"),
                    subtitle: L10n.s("more.float32Note"),
                    systemImage: "waveform",
                    badge: L10n.s("scope.tx"),
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
                    badge: L10n.s("scope.tx"),
                    isOn: startupRecordingBinding,
                    isEnabled: canEditTransmitterSettings
                )
            }
        }
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        SettingsSection(
            title: L10n.s("more.buttons"),
            systemImage: "hand.tap"
        ) {
            if supportsVibration {
                ToggleSettingRow(
                    title: L10n.s("more.vibration"),
                    subtitle: L10n.s("more.vibrationNote"),
                    systemImage: "iphone.radiowaves.left.and.right",
                    badge: L10n.s("scope.tx"),
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
                    badge: L10n.s("scope.tx"),
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
                    badge: L10n.s("scope.tx"),
                    isOn: micLEDBinding,
                    isEnabled: canEditMicLED
                )
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        SettingsSection(
            title: L10n.s("more.general"),
            systemImage: "gearshape"
        ) {
            ToggleSettingRow(
                title: L10n.s("more.autoOff"),
                subtitle: L10n.s("more.autoOffNote"),
                systemImage: "moon.zzz",
                badge: L10n.s("scope.tx"),
                isOn: autoOffBinding,
                isEnabled: canEditTransmitterSettings
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
