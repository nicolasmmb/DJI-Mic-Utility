import AppKit
import SwiftUI

public struct MenuBarPanel: View {
    @Bindable private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var moreExpanded = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            DeviceHeaderView(model: model)
            Divider()

            if let errorMessage = model.errorMessage {
                InlineErrorView(message: errorMessage)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
            }

            if !model.snapshot.connection.isConnected {
                disconnectedBanner
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ReceiverSectionView(model: model)

                    if model.snapshot.transmitters.isEmpty {
                        Text(L10n.s("tx.notConnected"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.snapshot.sortedTransmitters) { transmitter in
                            TransmitterSectionView(model: model, transmitter: transmitter)
                        }
                    }

                    Divider()

                    MoreSettingsView(model: model, isExpanded: $moreExpanded)
                }
                .padding(Spacing.md)
            }
            .frame(height: 500)

            Divider()
            footer
        }
        .frame(width: 380)
        .onAppear { model.start() }
    }

    private var disconnectedBanner: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "cable.connector.slash")
                .foregroundStyle(.orange)
            Text(L10n.s("status.disconnectedHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(L10n.s("menu.reconnect")) {
                model.reconnect()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            Button {
                openWindow(id: "diagnostics")
            } label: {
                Label(L10n.s("menu.diagnostics"), systemImage: "waveform.path.ecg")
            }
            .buttonStyle(.borderless)

            Spacer(minLength: 0)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label(L10n.s("menu.quit"), systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
        .font(.caption)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
}
