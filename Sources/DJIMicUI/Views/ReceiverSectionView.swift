import DJIMicProtocol
import SwiftUI

/// Stable projection of the receiver settings. Excludes fields that change at
/// status-push rate so the glass card is not rebuilt while scrolling.
struct ReceiverCardState: Equatable {
    var connected: Bool
    var hasReceiver: Bool
    var noiseCancelEnabled: Bool
    var noiseCancelStrong: Bool
    var gain: Int
    var monitoringGain: Int
    var stereo: Bool
    var safetyTrack: Bool
}

struct ReceiverSectionView: View {
    let model: AppModel

    private var state: ReceiverCardState {
        let receiver = model.snapshot.receiver
        return ReceiverCardState(
            connected: model.snapshot.connection.isConnected,
            hasReceiver: receiver != nil,
            noiseCancelEnabled: receiver?.noiseCancelEnabled ?? false,
            noiseCancelStrong: receiver?.noiseCancelStrong ?? false,
            gain: receiver?.gain ?? 0,
            monitoringGain: receiver?.monitoringGain ?? 0,
            stereo: receiver?.stereo ?? false,
            safetyTrack: receiver?.safetyTrack ?? false
        )
    }

    var body: some View {
        ReceiverCardBody(model: model, state: state)
            .equatable()
    }
}

private struct ReceiverCardBody: View, Equatable {
    let model: AppModel
    let state: ReceiverCardState

    static func == (lhs: ReceiverCardBody, rhs: ReceiverCardBody) -> Bool {
        lhs.state == rhs.state
    }

    private var isEditable: Bool {
        state.connected && state.hasReceiver
    }

    private var gainBinding: Binding<Int> {
        Binding(get: { state.gain }, set: { model.send(.gain($0)) })
    }

    private var stereoBinding: Binding<Bool> {
        Binding(get: { state.stereo }, set: { model.send(.stereo($0)) })
    }

    private var safetyTrackBinding: Binding<Bool> {
        Binding(get: { state.safetyTrack }, set: { model.send(.safetyTrack($0)) })
    }

    var body: some View {
        SettingsSection(title: L10n.s("rx.title")) {
            if state.hasReceiver {
                receiverSettings
            } else {
                unavailableMessage
            }
        }
    }

    @ViewBuilder
    private var receiverSettings: some View {
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
                current: state.monitoringGain,
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
                    isEnabled: isEditable && !state.stereo,
                    label: L10n.s("rx.safetyTrack")
                )
            }
            .disabled(!isEditable)

            if state.stereo {
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
        noiseReductionRow
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

    private var noiseReductionRow: some View {
        SettingRow(
            title: L10n.s("rx.noiseReduction"),
            subtitle: L10n.s("rx.noiseReduction.locked"),
            systemImage: "waveform"
        ) {
            LockedValueBadge(value: noiseReductionLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.s("rx.noiseReduction")), \(noiseReductionLabel)")
    }

    private var noiseReductionLabel: String {
        switch (state.noiseCancelEnabled, state.noiseCancelStrong) {
        case (false, _): L10n.s("rx.noiseReduction.off")
        case (true, true): L10n.s("rx.noiseReduction.strong")
        case (true, false): L10n.s("rx.noiseReduction.basic")
        }
    }
}
