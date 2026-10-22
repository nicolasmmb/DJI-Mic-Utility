import DJIMicProtocol
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

    private var voiceToneBinding: Binding<VoiceTone> {
        model.settingBinding(
            get: { transmitter.voiceTone },
            setting: { .voiceTone($0, unit: transmitter.unit) }
        )
    }

    private var transmitterName: String? {
        model.snapshot.transmitterIdentities[transmitter.unit]?.productName
    }

    var body: some View {
        SettingsSection(
            title: L10n.format("tx.title", transmitter.unit),
            detail: transmitterName
        ) {
            SettingRow(title: L10n.s("tx.voiceTone")) {
                Picker("", selection: voiceToneBinding) {
                    ForEach(VoiceTone.allCases, id: \.self) { tone in
                        Text(voiceToneLabel(tone)).tag(tone)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
                .accessibilityLabel(L10n.s("tx.voiceTone"))
            }
            .disabled(!isEditable)

            SettingRow(title: L10n.s("tx.inputLevel")) {
                LevelMeter(level: transmitter.inputLevel)
                    .frame(width: 170)
            }

            Divider()
                .padding(.vertical, Spacing.xxs)

            HStack(spacing: Spacing.sm) {
                BatteryView(transmitter: transmitter)
                Spacer(minLength: 0)
                findButton
            }
            .frame(minHeight: 26)
        }
    }

    private var findButton: some View {
        Button {
            model.findTransmitter(unit: transmitter.unit)
        } label: {
            Label(
                isFinding ? L10n.s("tx.find.finding") : L10n.s("tx.find"),
                systemImage: isFinding ? "light.beacon.max.fill" : "light.beacon.max"
            )
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!isEditable || model.findingUnit != nil)
        .accessibilityLabel(L10n.s("tx.find"))
        .accessibilityValue(isFinding ? L10n.s("tx.find.finding") : L10n.s("tx.find"))
        .help(L10n.s("tx.find.hint"))
    }

    private func voiceToneLabel(_ tone: VoiceTone) -> String {
        switch tone {
        case .regular: L10n.s("tx.voiceTone.regular")
        case .rich: L10n.s("tx.voiceTone.rich")
        case .bright: L10n.s("tx.voiceTone.bright")
        }
    }
}
