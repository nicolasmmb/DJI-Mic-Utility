import DJIMicProtocol
import SwiftUI

struct DeviceHeaderView: View {
    let model: AppModel
    /// Opens the device-wide settings page. Kept at the panel level so the
    /// entry point never looks like a per-transmitter action.
    var onMore: (() -> Void)?

    private var primaryTransmitter: TransmitterState? {
        model.snapshot.sortedTransmitters.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.snapshot.primaryIdentity?.productName ?? L10n.s("menu.noDevice"))
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    StatusBadge(connection: model.snapshot.connection)
                    if let firmware = model.snapshot.receiverIdentity?.firmware {
                        Text("fw \(firmware)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: Spacing.xs) {
                BatteryView(transmitter: primaryTransmitter)

                if let onMore {
                    Button(action: onMore) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.s("more.title"))
                    .accessibilityLabel(L10n.s("more.title"))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}
