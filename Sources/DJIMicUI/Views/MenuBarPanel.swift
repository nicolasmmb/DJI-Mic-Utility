import AppKit
import DJIMicProtocol
import SwiftUI

private enum PanelRoute {
    case main
    case moreSettings
}

public struct MenuBarPanel: View {
    @Bindable private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var route: PanelRoute = .main

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            errorBanner
            pageContent
            PanelFooter(
                onDiagnostics: openDiagnostics,
                onQuit: { NSApp.terminate(nil) }
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

    // MARK: - Header

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

            BatteryView(transmitter: primaryTransmitter)
        }
        .padding(.horizontal, PanelMetrics.contentInset)
    }

    // MARK: - Error banner

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = model.errorMessage {
            InlineErrorView(message: errorMessage)
                .padding(.horizontal, PanelMetrics.contentInset)
                .padding(.top, Spacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Pages

    private var pageContent: some View {
        ZStack {
            switch route {
            case .main:
                mainPage
                    .transition(pageTransition(forward: false))
            case .moreSettings:
                moreSettingsPage
                    .transition(pageTransition(forward: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.errorMessage)
    }

    private var mainPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if !model.snapshot.connection.isConnected {
                    disconnectedBanner
                }

                ReceiverSectionView(model: model)
                transmitterList
            }
            .padding(.horizontal, PanelMetrics.contentInset)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.automatic)
    }

    @ViewBuilder
    private var transmitterList: some View {
        let transmitters = model.snapshot.sortedTransmitters

        if transmitters.isEmpty {
            Text(L10n.s("tx.notConnected"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
        } else {
            ForEach(transmitters) { transmitter in
                TransmitterSectionView(
                    model: model,
                    transmitter: transmitter,
                    onMore: onMoreAction(for: transmitter, in: transmitters)
                )
            }
        }
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

    // MARK: - Actions

    private var primaryTransmitter: TransmitterState? {
        model.snapshot.sortedTransmitters.first
    }

    /// Only the first transmitter exposes the shortcut to the secondary
    /// settings page.
    private func onMoreAction(
        for transmitter: TransmitterState,
        in transmitters: [TransmitterState]
    ) -> (() -> Void)? {
        guard transmitter.unit == transmitters.first?.unit else { return nil }
        return { navigate(to: .moreSettings) }
    }

    private func openDiagnostics() {
        openWindow(id: "diagnostics")
        NSApp.activate()
    }

    private func navigate(to destination: PanelRoute) {
        guard !reduceMotion else {
            route = destination
            return
        }
        withAnimation(.snappy(duration: 0.28)) {
            route = destination
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
