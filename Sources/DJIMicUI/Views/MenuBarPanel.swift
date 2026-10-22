import AppKit
import SwiftUI

private enum PanelRoute {
    case main
    case moreSettings
}

public struct MenuBarPanel: View {
    @Bindable private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var route: PanelRoute = .main
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let errorMessage = model.errorMessage {
                InlineErrorView(message: errorMessage)
                    .padding(.horizontal, PanelMetrics.contentInset)
                    .padding(.top, Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                if route == .main {
                    mainPage
                        .transition(pageTransition(forward: false))
                } else {
                    moreSettingsPage
                        .transition(pageTransition(forward: true))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.errorMessage)

            PanelFooter(
                onDiagnostics: {
                    openWindow(id: "diagnostics")
                    NSApp.activate()
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        }
        .frame(width: PanelMetrics.width, height: PanelMetrics.height)
        .background(.regularMaterial)
        .onAppear { model.start() }
        .onExitCommand {
            guard route == .moreSettings else { return }
            navigate(to: .main)
        }
    }

    @ViewBuilder
    private var header: some View {
        Group {
            switch route {
            case .main:
                DeviceHeaderView(model: model)
            case .moreSettings:
                moreSettingsHeader
            }
        }
        .frame(height: 64)
    }

    private var moreSettingsHeader: some View {
        HStack(spacing: Spacing.sm) {
            BackButton {
                navigate(to: .main)
            }
            .keyboardShortcut(.cancelAction)

            Text(L10n.s("more.title"))
                .font(.headline)

            Spacer(minLength: 0)

            BatteryView(transmitter: model.snapshot.sortedTransmitters.first)
        }
        .padding(.horizontal, PanelMetrics.contentInset)
    }

    private var mainPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if !model.snapshot.connection.isConnected {
                    disconnectedBanner
                }

                ReceiverSectionView(model: model)

                if model.snapshot.transmitters.isEmpty {
                    Text(L10n.s("tx.notConnected"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)
                } else {
                    ForEach(model.snapshot.sortedTransmitters) { transmitter in
                        TransmitterSectionView(
                            model: model,
                            transmitter: transmitter,
                            onMore: transmitter.unit == model.snapshot.sortedTransmitters.first?.unit
                                ? { withAnimation { route = .moreSettings } }
                                : nil
                        )
                    }
                }

            }
            .padding(.horizontal, PanelMetrics.contentInset)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.automatic)
    }

    private var moreSettingsPage: some View {
        ScrollView {
            MoreSettingsContent(model: model)
                .padding(.horizontal, PanelMetrics.contentInset)
                .padding(.vertical, Spacing.sm)
        }
        .scrollIndicators(.automatic)
    }

    private var disconnectedBanner: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "cable.connector.slash")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(L10n.s("status.disconnectedHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(L10n.s("menu.reconnect")) {
                model.reconnect()
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.medium))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func navigate(to destination: PanelRoute) {
        if reduceMotion {
            route = destination
        } else {
            withAnimation(.snappy(duration: 0.28)) {
                route = destination
            }
        }
    }

    private func pageTransition(forward: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let edge: Edge = forward ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .move(edge: edge).combined(with: .opacity)
        )
    }
}
