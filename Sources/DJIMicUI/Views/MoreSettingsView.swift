import DJIMicProtocol
import SwiftUI

struct MoreSettingsView: View {
    let model: AppModel
    @Binding var isExpanded: Bool

    private var transmitter: TransmitterState? {
        model.snapshot.sortedTransmitters.first
    }

    private var receiver: ReceiverState? {
        model.snapshot.receiver
    }

    private var enabled: Bool {
        model.snapshot.connection.isConnected && transmitter != nil
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SettingsSection(title: L10n.s("more.audio")) {
                    SettingRow(title: L10n.s("more.lowCut")) {
                        Toggle("", isOn: lowCutBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(L10n.s("more.lowCut"))
                    }
                    .disabled(!enabled)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        SettingRow(title: L10n.s("more.clipping")) {
                            Toggle("", isOn: clippingBinding)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityLabel(L10n.s("more.clipping"))
                        }
                        .disabled(!enabled || receiver == nil)

                        Text(L10n.s("more.clippingNote"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SettingsSection(title: L10n.s("more.buttons")) {
                    SettingRow(title: L10n.s("more.micLED")) {
                        Toggle("", isOn: micLEDBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(L10n.s("more.micLED"))
                    }
                    .disabled(!enabled)
                }

                SettingsSection(title: L10n.s("more.general")) {
                    SettingRow(title: L10n.s("more.autoOff")) {
                        Toggle("", isOn: autoOffBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(L10n.s("more.autoOff"))
                    }
                    .disabled(!enabled)
                }
            }
            .padding(.top, Spacing.sm)
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
                Text(L10n.s("more.title"))
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
    }

    private var lowCutBinding: Binding<Bool> {
        Binding(
            get: { transmitter?.lowCut ?? false },
            set: { newValue in
                let current = transmitter?.lowCut ?? false
                guard newValue != current else { return }
                model.send(.lowCut(newValue))
            }
        )
    }

    private var clippingBinding: Binding<Bool> {
        Binding(
            get: { receiver?.clippingControl ?? false },
            set: { newValue in
                let current = receiver?.clippingControl ?? false
                guard newValue != current else { return }
                model.send(.clippingControl(newValue))
            }
        )
    }

    private var micLEDBinding: Binding<Bool> {
        Binding(
            get: { !(transmitter?.ledsOff ?? true) },
            set: { newValue in
                let current = !(transmitter?.ledsOff ?? true)
                guard newValue != current else { return }
                model.send(.micLED(newValue))
            }
        )
    }

    private var autoOffBinding: Binding<Bool> {
        Binding(
            get: { transmitter?.autoOff ?? false },
            set: { newValue in
                let current = transmitter?.autoOff ?? false
                guard newValue != current else { return }
                model.send(.autoOffTX(newValue))
            }
        )
    }
}
