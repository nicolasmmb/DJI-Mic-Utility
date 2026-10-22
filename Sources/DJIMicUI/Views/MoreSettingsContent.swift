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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            transmitterSection
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
