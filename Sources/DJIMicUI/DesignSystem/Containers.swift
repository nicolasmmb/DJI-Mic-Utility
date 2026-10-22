import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String?
    @ViewBuilder var content: Content

    init(
        title: String,
        action: (() -> Void)? = nil,
        actionTitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
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
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            SectionHeader(title: title)
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
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            content
        }
        .frame(minHeight: 26)
    }
}

/// Standard switch row used by the secondary settings pages.
struct ToggleSettingRow: View {
    let title: String
    let isOn: Binding<Bool>
    var isEnabled = true

    var body: some View {
        SettingRow(title: title) {
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
