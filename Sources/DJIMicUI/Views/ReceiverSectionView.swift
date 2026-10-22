import DJIMicProtocol
import SwiftUI

struct ReceiverSectionView: View {
    let model: AppModel

    private var receiver: ReceiverState? {
        model.snapshot.receiver
    }

    private var isEditable: Bool {
        model.snapshot.connection.isConnected && receiver != nil
    }

    private var gainBinding: Binding<Int> {
        model.settingBinding(get: { receiver?.gain ?? 0 }, setting: { .gain($0) })
    }

    private var stereoBinding: Binding<Bool> {
        model.settingBinding(get: { receiver?.stereo ?? false }, setting: { .stereo($0) })
    }

    private var safetyTrackBinding: Binding<Bool> {
        model.settingBinding(
            get: { receiver?.safetyTrack ?? false },
            setting: { .safetyTrack($0) }
        )
    }

    var body: some View {
        SettingsSection(title: L10n.s("rx.title")) {
            if let receiver {
                receiverSettings(receiver)
            } else {
                unavailableMessage
            }
        }
    }

    @ViewBuilder
    private func receiverSettings(_ receiver: ReceiverState) -> some View {
        SettingsGroupLabel(title: L10n.s("rx.group.levels"))

        SettingRow(
            title: L10n.s("rx.gain"),
            systemImage: "slider.horizontal.3"
        ) {
            SegmentedChipSelector(
                selection: gainBinding,
                values: [-12, -6, 0, 6, 12],
                isEnabled: isEditable,
                label: gainLabel
            )
        }

        SettingRow(title: L10n.s("rx.monitoringGain")) {
            MonitoringGainSlider(
                current: receiver.monitoringGain,
                isEnabled: isEditable
            ) { model.send(.monitoringGain($0)) }
        }

        Divider()
            .padding(.vertical, 2)

        SettingsGroupLabel(title: L10n.s("rx.group.channel"))

        SettingRow(
            title: L10n.s("rx.audioChannel"),
            systemImage: "rectangle.split.2x1"
        ) {
            SegmentedChipSelector(
                selection: stereoBinding,
                values: [false, true],
                isEnabled: isEditable,
                label: { isStereo in
                    L10n.s(isStereo ? "rx.audioChannel.stereo" : "rx.audioChannel.mono")
                }
            )
        }

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            SettingRow(
                title: L10n.s("rx.safetyTrack"),
                systemImage: "shield.lefthalf.filled"
            ) {
                ChipSwitch(
                    isOn: safetyTrackBinding,
                    isEnabled: isEditable && !receiver.stereo,
                    label: L10n.s("rx.safetyTrack")
                )
            }
            .disabled(!isEditable)

            if receiver.stereo {
                Text(L10n.s("rx.safetyTrack.monoOnly"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 32)
            }
        }

        Divider()
            .padding(.vertical, 2)

        SettingsGroupLabel(title: L10n.s("rx.group.noise"))
        noiseReductionRow(receiver)
    }

    private var unavailableMessage: some View {
        Text(L10n.s("rx.unavailable"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func gainLabel(_ value: Int) -> String {
        switch value {
        case 0: "0"
        case let positive where positive > 0: "+\(positive)"
        default: "\(value)"
        }
    }

    private func noiseReductionRow(_ receiver: ReceiverState) -> some View {
        SettingRow(
            title: L10n.s("rx.noiseReduction"),
            subtitle: L10n.s("rx.noiseReduction.locked"),
            systemImage: "waveform"
        ) {
            LockedValueBadge(value: noiseReductionLabel(receiver))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.s("rx.noiseReduction")), \(noiseReductionLabel(receiver))")
    }

    private func noiseReductionLabel(_ receiver: ReceiverState) -> String {
        switch (receiver.noiseCancelEnabled, receiver.noiseCancelStrong) {
        case (false, _): L10n.s("rx.noiseReduction.off")
        case (true, true): L10n.s("rx.noiseReduction.strong")
        case (true, false): L10n.s("rx.noiseReduction.basic")
        }
    }
}

