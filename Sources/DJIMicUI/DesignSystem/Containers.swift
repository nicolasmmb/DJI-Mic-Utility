import SwiftUI

struct SectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 2)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var systemImage: String?
    var footnote: String?
    var action: (() -> Void)?
    var actionTitle: String?
    @ViewBuilder var content: Content

    init(
        title: String,
        systemImage: String? = nil,
        footnote: String? = nil,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.footnote = footnote
        self.action = action
        self.actionTitle = actionTitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            header
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 10)
            .background(
                .quaternary.opacity(0.28),
                in: RoundedRectangle(cornerRadius: PanelMetrics.cardRadius, style: .continuous)
            )

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            SectionHeader(title: title, systemImage: systemImage)
            Spacer(minLength: 0)

            if let action, let actionTitle {
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
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .center)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
        .frame(minHeight: 26)
    }
}

/// Standard switch row used by the secondary settings pages.
struct ToggleSettingRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    let isOn: Binding<Bool>
    var isEnabled = true

    var body: some View {
        SettingRow(title: title, subtitle: subtitle, systemImage: systemImage) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(title)
        }
        .disabled(!isEnabled)
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.s("nav.back"))
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
            .padding(.trailing, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(L10n.s("nav.back"))
    }
}
