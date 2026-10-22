import DJIMicProtocol
import SwiftUI

struct ReceiverSectionView: View {
    let model: AppModel

    private var receiver: ReceiverState? {
        model.snapshot.receiver
    }

    private var enabled: Bool {
        model.snapshot.connection.isConnected && receiver != nil
    }

    var body: some View {
        SettingsSection(title: L10n.s("rx.title")) {
            if let receiver {
                noiseReductionRow(receiver)

                SettingRow(title: L10n.s("rx.gain")) {
                    Picker("", selection: gainBinding(receiver)) {
                        ForEach([-12, -6, 0, 6, 12], id: \.self) { value in
                            Text(value == 0 ? "0" : (value > 0 ? "+\(value)" : "\(value)"))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                    .accessibilityLabel(L10n.s("rx.gain"))
                }
                .disabled(!enabled)

                MonitoringGainRow(
                    current: receiver.monitoringGain,
                    enabled: enabled,
                    commit: { model.send(.monitoringGain($0)) }
                )

                SettingRow(title: L10n.s("rx.audioChannel")) {
                    Picker("", selection: stereoBinding(receiver)) {
                        Text(L10n.s("rx.audioChannel.mono")).tag(false)
                        Text(L10n.s("rx.audioChannel.stereo")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 150)
                    .accessibilityLabel(L10n.s("rx.audioChannel"))
                }
                .disabled(!enabled)

                SettingRow(title: L10n.s("rx.safetyTrack")) {
                    Toggle("", isOn: safetyBinding(receiver))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel(L10n.s("rx.safetyTrack"))
                }
                .disabled(!enabled)
            } else {
                Text(L10n.s("rx.unavailable"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func noiseReductionRow(_ receiver: ReceiverState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            SettingRow(title: L10n.s("rx.noiseReduction")) {
                HStack(spacing: Spacing.xxs) {
                    Text(noiseReductionLabel(receiver))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(L10n.s("rx.noiseReduction")), \(noiseReductionLabel(receiver))")

            Text(L10n.s("rx.noiseReduction.locked"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func noiseReductionLabel(_ receiver: ReceiverState) -> String {
        guard receiver.noiseCancelEnabled else {
            return L10n.s("rx.noiseReduction.off")
        }
        return receiver.noiseCancelStrong
            ? L10n.s("rx.noiseReduction.strong")
            : L10n.s("rx.noiseReduction.basic")
    }

    private func gainBinding(_ receiver: ReceiverState) -> Binding<Int> {
        Binding(
            get: { receiver.gain },
            set: { newValue in
                guard newValue != receiver.gain else { return }
                model.send(.gain(newValue))
            }
        )
    }

    private func stereoBinding(_ receiver: ReceiverState) -> Binding<Bool> {
        Binding(
            get: { receiver.stereo },
            set: { newValue in
                guard newValue != receiver.stereo else { return }
                model.send(.stereo(newValue))
            }
        )
    }

    private func safetyBinding(_ receiver: ReceiverState) -> Binding<Bool> {
        Binding(
            get: { receiver.safetyTrack },
            set: { newValue in
                guard newValue != receiver.safetyTrack else { return }
                model.send(.safetyTrack(newValue))
            }
        )
    }
}

private struct MonitoringGainRow: View {
    let current: Int
    let enabled: Bool
    let commit: (Int) -> Void

    @State private var value: Double = 0

    var body: some View {
        SettingRow(title: L10n.s("rx.monitoringGain")) {
            HStack(spacing: Spacing.xs) {
                Slider(value: $value, in: -12...12, onEditingChanged: { editing in
                    guard !editing else { return }
                    let rounded = Int(value.rounded())
                    value = Double(rounded)
                    commit(rounded)
                })
                .frame(width: 120)
                .accessibilityLabel(L10n.s("rx.monitoringGain"))

                Text("\(Int(value.rounded())) dB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .disabled(!enabled)
        .onAppear { value = Double(current) }
        .onChange(of: current) { _, newValue in
            value = Double(newValue)
        }
    }
}
