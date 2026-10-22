import AppKit
import DJIMicProtocol
import SwiftUI
import UniformTypeIdentifiers

public struct DiagnosticsView: View {
    @Bindable private var model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            summary

            Divider()

            HStack {
                Text(L10n.s("diag.frames"))
                    .font(.headline)
                Spacer()
                Button(L10n.s("diag.reconnect")) {
                    model.reconnect()
                }
                Button(L10n.s("diag.clear")) {
                    model.clearDiagnostics()
                }
                Button(L10n.s("diag.export")) {
                    export()
                }
            }

            ScrollView {
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
            }
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Spacer()
                Button(L10n.s("diag.close")) {
                    dismissWindow(id: "diagnostics")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.lg)
        .frame(minWidth: 600, minHeight: 380)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.snapshot.primaryIdentity?.productName ?? L10n.s("diag.none"))
                    .font(.title3.weight(.semibold))
                Spacer()
                StatusBadge(connection: model.snapshot.connection)
            }

            Grid(alignment: .leading, horizontalSpacing: Spacing.lg, verticalSpacing: Spacing.xxs) {
                infoRow(L10n.s("diag.firmware"), model.snapshot.receiverIdentity?.firmware)
                infoRow(L10n.s("diag.serial"), model.snapshot.receiverIdentity?.serial)
                infoRow(L10n.s("diag.address"), model.snapshot.receiverIdentity?.addressSuffix)
                infoRow(L10n.s("diag.device"), model.snapshot.transmitterIdentities
                    .sorted { $0.key < $1.key }
                    .map { "TX\($0.key): \($0.value.productName)" }
                    .joined(separator: "  "))
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String?) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value.flatMap { $0.isEmpty ? nil : $0 } ?? "—")
                .textSelection(.enabled)
                .monospacedDigit()
        }
    }

    private var logText: String {
        if model.diagnosticLines.isEmpty {
            return L10n.s("diag.empty")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return model.diagnosticLines
            .map { "\(formatter.string(from: $0.timestamp))  \($0.text)" }
            .joined(separator: "\n")
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "dji-mic-diagnostics.jsonl"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? model.diagnosticsJSONL().write(to: url, atomically: true, encoding: .utf8)
    }
}
