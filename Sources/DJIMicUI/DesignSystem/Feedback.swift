import SwiftUI

struct InlineErrorView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.orange.opacity(0.15), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct PanelFooter: View {
    let onDiagnostics: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onDiagnostics) {
                Label(L10n.s("menu.diagnostics"), systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            Spacer(minLength: 0)

            Button(action: onQuit) {
                Label(L10n.s("menu.quit"), systemImage: "power")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, PanelMetrics.contentInset)
        .frame(height: PanelMetrics.footerHeight)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
