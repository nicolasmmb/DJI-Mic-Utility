import Foundation
import UserNotifications

public protocol NotificationDelivering: AnyObject {
    func configure()
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func post(_ alert: MicAlert, preferences: NotificationPreferences) async
    func removeDelivered(_ identifier: String)
}

public final class MicNotificationCenter: NSObject, NotificationDelivering, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = MicNotificationCenter()

    private enum Category {
        static let linkLost = "MIC_LINK_LOST"
        static let recordingStopped = "MIC_RECORDING_STOPPED"
        static let reconnect = "MIC_RECONNECT"
        static let rerecord = "MIC_RERECORD"
    }

    private enum UserInfoKey {
        static let unit = "unit"
    }

    // `UNUserNotificationCenter.current()` requires a real application bundle.
    // Keep it lazy so test bundles and previews can reference the singleton.
    private lazy var center = UNUserNotificationCenter.current()
    private let actionLock = NSLock()
    private var actionHandler: ((MicNotificationAction) -> Void)?
    private var pendingActions: [MicNotificationAction] = []
    private let stateLock = NSLock()
    private var configured = false

    public var onAction: ((MicNotificationAction) -> Void)? {
        get {
            actionLock.lock()
            defer { actionLock.unlock() }
            return actionHandler
        }
        set {
            actionLock.lock()
            actionHandler = newValue
            let pending = pendingActions
            pendingActions.removeAll()
            actionLock.unlock()

            if let newValue {
                pending.forEach(newValue)
            }
        }
    }

    private var isConfigured: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return configured
    }

    public func configure() {
        // A real .app bundle is required by UNUserNotificationCenter.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        stateLock.lock()
        if configured {
            stateLock.unlock()
            return
        }
        configured = true
        stateLock.unlock()

        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Category.linkLost,
                actions: [
                    UNNotificationAction(
                        identifier: Category.reconnect,
                        title: L10n.s("notif.action.reconnect")
                    )
                ],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: Category.recordingStopped,
                actions: [
                    UNNotificationAction(
                        identifier: Category.rerecord,
                        title: L10n.s("notif.action.rerecord")
                    )
                ],
                intentIdentifiers: [],
                options: []
            ),
        ])
    }

    public func requestAuthorization() async -> Bool {
        guard isConfigured else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        guard isConfigured else { return .notDetermined }
        return await center.notificationSettings().authorizationStatus
    }

    public func post(_ alert: MicAlert, preferences: NotificationPreferences) async {
        guard isConfigured, preferences.allows(alert) else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            return
        }

        switch alert {
        case .receiverConnected:
            removeDelivered("link.rx")
        case .transmitterConnected(let unit, _, _, _):
            removeDelivered("disconnect.tx.\(unit)")
        default:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = title(for: alert)
        content.body = body(for: alert)
        content.threadIdentifier = alert.threadIdentifier
        content.categoryIdentifier = category(for: alert)
        content.userInfo = userInfo(for: alert)

        switch alert {
        case .lowBattery, .transmitterDisconnected, .recordingStopped, .linkLost:
            content.sound = .default
        case .receiverConnected, .transmitterConnected:
            content.sound = nil
        }

        let request = UNNotificationRequest(
            identifier: alert.identifier,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    public func removeDelivered(_ identifier: String) {
        guard isConfigured else { return }
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Delegate

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch action {
        case Category.reconnect:
            dispatch(.reconnect)
        case Category.rerecord:
            if let unit = userInfo[UserInfoKey.unit] as? Int {
                dispatch(.rerecord(unit: unit))
            }
        default:
            break
        }
        completionHandler()
    }

    private func dispatch(_ action: MicNotificationAction) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.actionLock.lock()
            if let handler = self.actionHandler {
                self.actionLock.unlock()
                handler(action)
            } else {
                self.pendingActions.append(action)
                self.actionLock.unlock()
            }
        }
    }

    // MARK: - Content

    private func title(for alert: MicAlert) -> String {
        switch alert {
        case .receiverConnected:
            L10n.s("notif.receiver.connected.title")
        case .transmitterConnected(let unit, _, _, _):
            L10n.format("notif.tx.connected.title", unit)
        case .lowBattery(let unit, _, _):
            L10n.format("notif.battery.low.title", unit)
        case .transmitterDisconnected(let unit, _):
            L10n.format("notif.tx.disconnected.title", unit)
        case .recordingStopped(let unit, _):
            L10n.format("notif.recording.stopped.title", unit)
        case .linkLost:
            L10n.s("notif.link.lost.title")
        }
    }

    private func body(for alert: MicAlert) -> String {
        switch alert {
        case .receiverConnected(let name):
            return name ?? L10n.s("notif.receiver.connected.body")
        case .transmitterConnected(_, let name, let batteryGauge, let charging):
            let battery = batteryDescription(gauge: batteryGauge, charging: charging)
            return "\(name ?? "") · \(battery)"
        case .lowBattery:
            return L10n.s("notif.battery.low.body")
        case .transmitterDisconnected:
            return L10n.s("notif.tx.disconnected.body")
        case .recordingStopped:
            return L10n.s("notif.recording.stopped.body")
        case .linkLost:
            return L10n.s("notif.link.lost.body")
        }
    }

    private func batteryDescription(gauge: Int, charging: Bool) -> String {
        if charging {
            return L10n.s("notif.battery.charging")
        }
        let level: String
        switch gauge {
        case 1:
            level = L10n.s("battery.full")
        case 2, 3:
            level = L10n.s("battery.good")
        case 4, 5:
            level = L10n.s("battery.medium")
        case 6:
            level = L10n.s("battery.low")
        default:
            level = L10n.s("battery.empty")
        }
        return L10n.format("notif.battery.label", level)
    }

    private func category(for alert: MicAlert) -> String {
        switch alert {
        case .linkLost: Category.linkLost
        case .recordingStopped: Category.recordingStopped
        default: ""
        }
    }

    private func userInfo(for alert: MicAlert) -> [String: Any] {
        switch alert {
        case .transmitterConnected(let unit, _, _, _),
             .lowBattery(let unit, _, _),
             .transmitterDisconnected(let unit, _),
             .recordingStopped(let unit, _):
            return [UserInfoKey.unit: unit]
        default:
            return [:]
        }
    }
}
