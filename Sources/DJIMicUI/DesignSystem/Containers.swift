import SwiftUI

struct SettingsGroupLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SectionHeader: View {
    let title: String
    var systemImage: String?
    /// Secondary text shown next to the title, such as a model name.
    var detail: String?

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(1)

            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.leading, 4)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var systemImage: String?
    var detail: String?
    var footnote: String?
    var action: (() -> Void)?
    var actionTitle: String?
    var headerTrailing: AnyView?
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        systemImage: String? = nil,
        detail: String? = nil,
        footnote: String? = nil,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil,
        headerTrailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.detail = detail
        self.footnote = footnote
        self.action = action
        self.actionTitle = actionTitle
        self.headerTrailing = headerTrailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .environment(\.colorScheme, colorScheme)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .glassPanel(cornerRadius: PanelMetrics.cardRadius)

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            SectionHeader(title: title, systemImage: systemImage, detail: detail)
            Spacer(minLength: 0)

            if let headerTrailing {
                headerTrailing
            } else if let action, let actionTitle {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(actionTitle)
            }
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var info: String?
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .center)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if let info {
                        SettingInfoButton(title: title, message: info)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
        .frame(minHeight: 38)
    }
}

struct SettingInfoButton: View {
    let title: String
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false
    @State private var isHovering = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                .scaleEffect(isHovering && !reduceMotion ? 1.08 : 1)
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 260, alignment: .leading)
        }
        .accessibilityLabel(L10n.format("info.accessibility", title))
        .help(L10n.s("info.help"))
    }
}

/// Standard switch row used by the secondary settings pages.
struct ToggleSettingRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var info: String?
    let isOn: Binding<Bool>
    var isEnabled = true

    var body: some View {
        SettingRow(title: title, subtitle: subtitle, systemImage: systemImage, info: info) {
            ChipSwitch(isOn: isOn, isEnabled: isEnabled, label: title)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

struct BackButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Text(L10n.s("nav.back"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .glassCapsule()
            .contentShape(Capsule())
        }
        .buttonStyle(PressableChipButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(L10n.s("nav.back"))
    }
}
