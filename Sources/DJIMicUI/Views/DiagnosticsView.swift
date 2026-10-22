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
        VStack(spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: Spacing.md) {
                deviceSection
                framesToolbar
                logView
                footer
            }
            .padding(Spacing.md)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.s("app.name"))
                    .font(.headline)

                Text(L10n.s("diag.title"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            StatusBadge(connection: model.snapshot.connection)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Device

    private var deviceSection: some View {
        SettingsSection(title: L10n.s("diag.deviceInfo"), systemImage: "cpu") {
            VStack(alignment: .leading, spacing: 8) {
                Grid(alignment: .leading, horizontalSpacing: Spacing.md, verticalSpacing: 8) {
                    GridRow {
                        infoLabel(L10n.s("diag.deviceName"))
                        infoValue(model.snapshot.receiverDisplayName)
                        infoLabel(L10n.s("diag.serial"))
                        infoValue(model.snapshot.receiverIdentity?.serial, monospaced: true)
                    }

                    GridRow {
                        infoLabel(L10n.s("diag.protocolName"))
                        infoValue(model.snapshot.receiverIdentity?.productName)
                        infoLabel(L10n.s("diag.firmware"))
                        infoValue(model.snapshot.receiverIdentity?.firmware, monospaced: true)
                    }

                    GridRow {
                        infoLabel(L10n.s("diag.address"))
                        infoValue(model.snapshot.receiverIdentity?.addressSuffix, monospaced: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    infoLabel(L10n.s("diag.device"))
                    infoValue(transmitterSummary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func infoLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 84, alignment: .leading)
    }

    private func infoValue(_ value: String?, monospaced: Bool = false) -> some View {
        Text(nonEmpty(value) ?? "—")
            .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
            .textSelection(.enabled)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Frames

    private var framesToolbar: some View {
        HStack(spacing: Spacing.xs) {
            Text(L10n.s("diag.frames"))
                .font(.headline)

            Spacer(minLength: 0)

            ChipButton(title: L10n.s("diag.reconnect"), systemImage: "arrow.clockwise") {
                model.reconnect()
            }

            ChipButton(title: L10n.s("diag.clear"), systemImage: "trash") {
                model.clearDiagnostics()
            }

            ChipButton(title: L10n.s("diag.export"), systemImage: "square.and.arrow.up") {
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
        .frame(maxHeight: .infinity)
        .background(
            .secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.sm) {
            Text(L10n.format("diag.frameCount", model.diagnosticLines.count))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Spacer(minLength: 0)

            ChipButton(
                title: L10n.s("diag.close"),
                systemImage: "xmark",
                shortcut: .defaultAction
            ) {
                dismissWindow(id: "diagnostics")
            }
        }
    }

    // MARK: - Content

    private var transmitterSummary: String {
        let names = model.snapshot.transmitterIdentities.keys.sorted().compactMap {
            model.snapshot.transmitterDiagnosticName(unit: $0)
        }

        guard !names.isEmpty else {
            let units = model.snapshot.transmitters.keys.sorted().map { "TX\($0)" }
            return units.joined(separator: "  ")
        }

        return names.joined(separator: "  ")
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
