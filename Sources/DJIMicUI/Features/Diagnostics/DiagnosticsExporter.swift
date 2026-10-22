import AppKit
import UniformTypeIdentifiers

/// Presents the save panel and writes the diagnostics export.
enum DiagnosticsExporter {
    static func export(_ contents: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "dji-mic-diagnostics.jsonl"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
