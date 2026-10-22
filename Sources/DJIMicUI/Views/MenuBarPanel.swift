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
                .opacity(0.25)
            errorBanner
            pageContent
        }
        .frame(width: PanelMetrics.width, height: PanelMetrics.height)
        .background(PremiumBackdrop())
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
                DeviceHeaderView(
                    model: model,
                    onMore: { navigate(to: .moreSettings) },
                    onDiagnostics: openDiagnostics,
                    onQuit: quit
                )
            case .moreSettings:
                moreSettingsHeader
            }
        }
        .frame(height: 84)
    }

    private var moreSettingsHeader: some View {
        HStack(spacing: 12) {
            BackButton {
                navigate(to: .main)
            }
            .keyboardShortcut(.cancelAction)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.s("more.title"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))

                Text(L10n.s("more.subtitle"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                HeaderIconButton(
                    systemImage: "waveform.path.ecg",
                    title: L10n.s("menu.diagnostics"),
                    action: openDiagnostics
                )

                HeaderIconButton(
                    systemImage: "power",
                    title: L10n.s("menu.quit"),
                    action: quit
                )
            }
        }
        .padding(.horizontal, PanelMetrics.contentInset)
        .padding(.vertical, 14)
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
            VStack(alignment: .leading, spacing: 20) {
                if !model.snapshot.connection.isConnected {
                    disconnectedBanner
                }

                ReceiverSectionView(model: model)
                transmitterList
            }
            .padding(.horizontal, PanelMetrics.contentInset)
            .padding(.vertical, 14)
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
                    transmitter: transmitter
                )
            }
        }
    }

    private var moreSettingsPage: some View {
        ScrollView {
            MoreSettingsContent(model: model)
                .padding(.horizontal, PanelMetrics.contentInset)
                .padding(.vertical, 14)
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

    private func openDiagnostics() {
        openWindow(id: "diagnostics")
        NSApp.activate()
    }

    private func quit() {
        NSApp.terminate(nil)
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
