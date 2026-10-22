import DJIMicProtocol
import SwiftUI

struct DeviceHeaderView: View {
    let model: AppModel
    /// Opens the device-wide settings page. Kept at the panel level so the
    /// entry point never looks like a per-transmitter action.
    var onMore: (() -> Void)?
    var onDiagnostics: (() -> Void)?
    var onQuit: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .glassPanel(cornerRadius: 14)
                .accessibilityHidden(true)

            // The header is app-level, not per-device: it must not show a
            // transmitter's model or battery, since a kit can have two
            // transmitters (possibly different models).
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.s("app.name"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    StatusBadge(connection: model.snapshot.connection)
                    if let firmware = model.snapshot.receiverIdentity?.firmware {
                        Text("fw \(firmware)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }

            Spacer(minLength: 0)

            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    if let onMore {
                        HeaderIconButton(
                            systemImage: "slider.horizontal.3",
                            title: L10n.s("more.title"),
                            action: onMore
                        )
                    }

                    if let onDiagnostics {
                        HeaderIconButton(
                            systemImage: "waveform.path.ecg",
                            title: L10n.s("menu.diagnostics"),
                            action: onDiagnostics
                        )
                    }

                    if let onQuit {
                        HeaderIconButton(
                            systemImage: "power",
                            title: L10n.s("menu.quit"),
                            action: onQuit
                        )
                    }
                }
            }
        }
        .padding(.horizontal, PanelMetrics.contentInset)
        .padding(.vertical, 14)
    }
}
