import DJIMicUI
import SwiftUI

@main
struct DJIMicApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model)
        } label: {
            Image(systemName: model.snapshot.menuBarSymbol)
                .accessibilityLabel(L10n.s("app.name"))
        }
        .menuBarExtraStyle(.window)

        Window(L10n.s("diag.title"), id: "diagnostics") {
            DiagnosticsView(model: model)
        }
        .defaultSize(width: 640, height: 440)
    }
}
