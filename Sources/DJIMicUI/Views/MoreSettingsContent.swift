import DJIMicProtocol
import SwiftUI

/// Secondary settings page. Every row here is device-wide or broadcast to all
/// transmitters, so the layout groups rows by target device instead of by
/// feature, and the header never shows per-unit state (such as TX1's battery).
struct MoreSettingsContent: View {
    let model: AppModel

    private var transmitter: TransmitterState? {
        model.snapshot.sortedTransmitters.first
    }

    private var receiver: ReceiverState? {
        model.snapshot.receiver
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
        supportsVibration || supportsFloat32 || supportsStartupRecording || supportsRecStopLock
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            transmitterSection

            if supportsRecordingSection {
                recordingSection
            }

            receiverSection

            if !canEditTransmitterSettings {
                disconnectedHint
            }
        }
    }

    private var transmitterSection: some View {
        SettingsSection(
            title: L10n.s("more.transmitter"),
            systemImage: "mic.fill",
            footnote: L10n.s("more.transmitterNote")
        ) {
            ToggleSettingRow(
                title: L10n.s("more.lowCut"),
                subtitle: L10n.s("more.lowCutNote"),
                systemImage: "waveform.path.ecg",
                isOn: lowCutBinding,
                isEnabled: canEditTransmitterSettings
            )

            Divider()

            ToggleSettingRow(
                title: L10n.s("more.micLED"),
                subtitle: L10n.s("more.micLEDNote"),
                systemImage: "light.max",
                isOn: micLEDBinding,
                isEnabled: canEditMicLED
            )

            Divider()

            ToggleSettingRow(
                title: L10n.s("more.autoOff"),
                subtitle: L10n.s("more.autoOffNote"),
                systemImage: "moon.zzz",
                isOn: autoOffBinding,
                isEnabled: canEditTransmitterSettings
            )
        }
    }

    private var recordingSection: some View {
        SettingsSection(
            title: L10n.s("more.recording"),
            systemImage: "record.circle"
        ) {
            if supportsVibration {
                ToggleSettingRow(
                    title: L10n.s("more.vibration"),
                    subtitle: L10n.s("more.vibrationNote"),
                    systemImage: "iphone.radiowaves.left.and.right",
                    isOn: vibrationBinding,
                    isEnabled: canEditTransmitterSettings
                )
            }

            if supportsFloat32 {
                if supportsVibration { Divider() }

                ToggleSettingRow(
                    title: L10n.s("more.float32"),
                    subtitle: L10n.s("more.float32Note"),
                    systemImage: "waveform",
                    isOn: float32Binding,
                    isEnabled: canEditTransmitterSettings
                )
            }

            if supportsStartupRecording {
                if supportsVibration || supportsFloat32 { Divider() }

                ToggleSettingRow(
                    title: L10n.s("more.startupRecording"),
                    subtitle: L10n.s("more.startupRecordingNote"),
                    systemImage: "play.circle",
                    isOn: startupRecordingBinding,
                    isEnabled: canEditTransmitterSettings
                )
            }

            if supportsRecStopLock {
                if supportsVibration || supportsFloat32 || supportsStartupRecording {
                    Divider()
                }

                ToggleSettingRow(
                    title: L10n.s("more.recStopLock"),
                    subtitle: L10n.s("more.recStopLockNote"),
                    systemImage: "lock.circle",
                    isOn: recStopLockBinding,
                    isEnabled: canEditTransmitterSettings
                )
            }
        }
    }

    private var receiverSection: some View {
        SettingsSection(
            title: L10n.s("more.receiver"),
            systemImage: "dot.radiowaves.left.and.right"
        ) {
            ToggleSettingRow(
                title: L10n.s("more.clipping"),
                subtitle: L10n.s("more.clippingNote"),
                systemImage: "waveform.badge.exclamationmark",
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
