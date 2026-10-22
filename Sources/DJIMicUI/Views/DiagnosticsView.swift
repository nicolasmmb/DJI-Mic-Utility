import AppKit
import DJIMicProtocol
import SwiftUI

public struct DiagnosticsView: View {
    @Bindable private var model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow

    private static let logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            summary
            Divider()
            toolbar
            logView
            footer
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
                infoRow(L10n.s("diag.device"), transmitterSummary)
            }
            .font(.caption)
        }
    }

    private var toolbar: some View {
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
                DiagnosticsExporter.export(model.diagnosticsJSONL())
            }
        }
    }

    private var logView: some View {
        ScrollView {
            Text(logText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
        }
        .background(
            .quaternary.opacity(0.25),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(L10n.s("diag.close")) {
                dismissWindow(id: "diagnostics")
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var transmitterSummary: String {
        model.snapshot.transmitterIdentities
            .sorted { $0.key < $1.key }
            .map { "TX\($0.key): \($0.value.productName)" }
            .joined(separator: "  ")
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String?) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)

            Text(nonEmpty(value) ?? "—")
                .textSelection(.enabled)
                .monospacedDigit()
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private var logText: String {
        let lines = model.diagnosticLines
        guard !lines.isEmpty else { return L10n.s("diag.empty") }

        let formatter = Self.logTimestampFormatter
        return lines
            .map { "\(formatter.string(from: $0.timestamp))  \($0.text)" }
            .joined(separator: "\n")
    }
}
