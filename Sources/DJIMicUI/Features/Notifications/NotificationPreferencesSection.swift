import AppKit
import SwiftUI
import UserNotifications

struct NotificationPreferencesSection: View {
    let settings: NotificationSettings

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    private func binding(
        _ keyPath: ReferenceWritableKeyPath<NotificationSettings, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }

    var body: some View {
        SettingsSection(
            title: L10n.s("notifications.title"),
            systemImage: "bell.badge",
            footnote: L10n.s("notifications.subtitle")
        ) {
            ToggleSettingRow(
                title: L10n.s("notifications.enabled"),
                subtitle: L10n.s("notifications.enabled.note"),
                systemImage: "bell",
                isOn: binding(\.notificationsEnabled),
                isEnabled: true
            )

            Divider()

            permissionRow

            Divider()

            Group {
                SettingsGroupLabel(title: L10n.s("notifications.group.connection"))

                ToggleSettingRow(
                    title: L10n.s("notifications.receiverConnected"),
                    subtitle: L10n.s("notifications.receiverConnected.note"),
                    systemImage: "cable.connector",
                    isOn: binding(\.receiverConnected),
                    isEnabled: true
                )

                Divider()

                ToggleSettingRow(
                    title: L10n.s("notifications.transmitterConnected"),
                    subtitle: L10n.s("notifications.transmitterConnected.note"),
                    systemImage: "mic.fill",
                    isOn: binding(\.transmitterConnected),
                    isEnabled: true
                )

                Divider()

                ToggleSettingRow(
                    title: L10n.s("notifications.notifyOnLaunch"),
                    subtitle: L10n.s("notifications.notifyOnLaunch.note"),
                    systemImage: "power",
                    isOn: binding(\.notifyOnLaunchWhenConnected),
                    isEnabled: true
                )

                Divider()

                SettingsGroupLabel(title: L10n.s("notifications.group.alerts"))

                ToggleSettingRow(
                    title: L10n.s("notifications.lowBattery"),
                    subtitle: L10n.s("notifications.lowBattery.note"),
                    systemImage: "battery.25",
                    isOn: binding(\.lowBattery),
                    isEnabled: true
                )

                Divider()

                ToggleSettingRow(
                    title: L10n.s("notifications.txDisconnected"),
                    subtitle: L10n.s("notifications.txDisconnected.note"),
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    isOn: binding(\.transmitterDisconnected),
                    isEnabled: true
                )

                Divider()

                ToggleSettingRow(
                    title: L10n.s("notifications.recordingStopped"),
                    subtitle: L10n.s("notifications.recordingStopped.note"),
                    systemImage: "record.circle",
                    isOn: binding(\.recordingStopped),
                    isEnabled: true
                )

                Divider()

                ToggleSettingRow(
                    title: L10n.s("notifications.linkLost"),
                    subtitle: L10n.s("notifications.linkLost.note"),
                    systemImage: "cable.connector.slash",
                    isOn: binding(\.linkLost),
                    isEnabled: true
                )
            }
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1 : 0.55)
        }
        .task {
            authorizationStatus = await MicNotificationCenter.shared.authorizationStatus()
        }
    }

    @ViewBuilder
    private var permissionRow: some View {
        switch authorizationStatus {
        case .notDetermined:
            HStack(spacing: Spacing.sm) {
                Text(L10n.s("notifications.permission.label"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                ChipButton(
                    title: L10n.s("notifications.permission.allow"),
                    systemImage: "bell"
                ) {
                    requestAuthorization()
                }
                .disabled(isRequesting)
            }

        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.s("notifications.permission.deniedNote"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ChipButton(
                    title: L10n.s("notifications.permission.openSettings"),
                    systemImage: "gear"
                ) {
                    openNotificationSettings()
                }
            }

        default:
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                Text(L10n.s("notifications.permission.enabled"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                ChipButton(
                    title: L10n.s("notifications.test"),
                    systemImage: "bell.badge"
                ) {
                    Task {
                        var preferences = settings.snapshot
                        preferences.receiverConnected = true
                        await MicNotificationCenter.shared.post(
                            .receiverConnected(name: L10n.s("app.name")),
                            preferences: preferences
                        )
                    }
                }
                .disabled(!settings.notificationsEnabled)
            }
        }
    }

    private func requestAuthorization() {
        guard !isRequesting else { return }
        isRequesting = true
        Task {
            _ = await MicNotificationCenter.shared.requestAuthorization()
            authorizationStatus = await MicNotificationCenter.shared.authorizationStatus()
            isRequesting = false
        }
    }

    private func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
