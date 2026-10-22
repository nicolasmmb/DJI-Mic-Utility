import DJIMicProtocol
import SwiftUI

struct TransmitterSectionView: View {
    let model: AppModel
    let transmitter: TransmitterState
    var onMore: (() -> Void)?

    private var enabled: Bool {
        model.snapshot.connection.isConnected
    }

    var body: some View {
        SettingsSection(
            title: L10n.format("tx.title", transmitter.unit),
            action: onMore,
            actionTitle: onMore == nil ? nil : L10n.s("more.short")
        ) {
            SettingRow(title: L10n.s("tx.voiceTone")) {
                Picker("", selection: voiceToneBinding) {
                    Text(L10n.s("tx.voiceTone.regular")).tag(VoiceTone.regular)
                    Text(L10n.s("tx.voiceTone.rich")).tag(VoiceTone.rich)
                    Text(L10n.s("tx.voiceTone.bright")).tag(VoiceTone.bright)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
                .accessibilityLabel(L10n.s("tx.voiceTone"))
            }
            .disabled(!enabled)

            SettingRow(title: L10n.s("tx.inputLevel")) {
                LevelMeter(level: transmitter.inputLevel)
                    .frame(width: 170)
            }

            SettingRow(title: L10n.s("tx.battery")) {
                BatteryView(transmitter: transmitter)
            }
        }
    }

    private var voiceToneBinding: Binding<VoiceTone> {
        Binding(
            get: { transmitter.voiceTone },
            set: { newValue in
                guard newValue != transmitter.voiceTone else { return }
                model.send(.voiceTone(newValue, unit: transmitter.unit))
            }
        )
    }
}
