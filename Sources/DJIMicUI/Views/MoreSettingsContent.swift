import DJIMicProtocol
import SwiftUI

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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            audioSection
            buttonsSection
            generalSection

            if !canEditTransmitterSettings {
                Text(L10n.s("tx.notConnected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var audioSection: some View {
        SettingsSection(title: L10n.s("more.audio")) {
            ToggleSettingRow(
                title: L10n.s("more.lowCut"),
                isOn: lowCutBinding,
                isEnabled: canEditTransmitterSettings
            )

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ToggleSettingRow(
                    title: L10n.s("more.clipping"),
                    isOn: clippingBinding,
                    isEnabled: canEditReceiverSettings
                )

                Text(L10n.s("more.clippingNote"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var buttonsSection: some View {
        SettingsSection(title: L10n.s("more.buttons")) {
            ToggleSettingRow(
                title: L10n.s("more.micLED"),
                isOn: micLEDBinding,
                isEnabled: canEditMicLED
            )
        }
    }

    private var generalSection: some View {
        SettingsSection(title: L10n.s("more.general")) {
            ToggleSettingRow(
                title: L10n.s("more.autoOff"),
                isOn: autoOffBinding,
                isEnabled: canEditTransmitterSettings
            )
        }
    }
}
