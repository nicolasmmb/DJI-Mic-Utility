import Foundation
import Observation

public struct NotificationPreferences: Equatable, Sendable {
    public var enabled: Bool
    public var receiverConnected: Bool
    public var transmitterConnected: Bool
    public var notifyOnLaunchWhenConnected: Bool
    public var lowBattery: Bool
    public var transmitterDisconnected: Bool
    public var recordingStopped: Bool
    public var linkLost: Bool

    public init(
        enabled: Bool = true,
        receiverConnected: Bool = true,
        transmitterConnected: Bool = true,
        notifyOnLaunchWhenConnected: Bool = false,
        lowBattery: Bool = true,
        transmitterDisconnected: Bool = true,
        recordingStopped: Bool = true,
        linkLost: Bool = true
    ) {
        self.enabled = enabled
        self.receiverConnected = receiverConnected
        self.transmitterConnected = transmitterConnected
        self.notifyOnLaunchWhenConnected = notifyOnLaunchWhenConnected
        self.lowBattery = lowBattery
        self.transmitterDisconnected = transmitterDisconnected
        self.recordingStopped = recordingStopped
        self.linkLost = linkLost
    }

    public var anyEnabled: Bool {
        enabled && (receiverConnected || transmitterConnected || lowBattery ||
            transmitterDisconnected || recordingStopped || linkLost)
    }
}

@Observable
@MainActor
public final class NotificationSettings {
    private enum Key {
        static let prefix = "com.niko.djimic.notifications."
        static let enabled = prefix + "enabled"
        static let receiverConnected = prefix + "receiverConnected"
        static let transmitterConnected = prefix + "transmitterConnected"
        static let notifyOnLaunch = prefix + "notifyOnLaunchWhenConnected"
        static let lowBattery = prefix + "lowBattery"
        static let transmitterDisconnected = prefix + "transmitterDisconnected"
        static let recordingStopped = prefix + "recordingStopped"
        static let linkLost = prefix + "linkLost"
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Key.enabled) } }
    public var receiverConnected: Bool { didSet { defaults.set(receiverConnected, forKey: Key.receiverConnected) } }
    public var transmitterConnected: Bool { didSet { defaults.set(transmitterConnected, forKey: Key.transmitterConnected) } }
    public var notifyOnLaunchWhenConnected: Bool { didSet { defaults.set(notifyOnLaunchWhenConnected, forKey: Key.notifyOnLaunch) } }
    public var lowBattery: Bool { didSet { defaults.set(lowBattery, forKey: Key.lowBattery) } }
    public var transmitterDisconnected: Bool { didSet { defaults.set(transmitterDisconnected, forKey: Key.transmitterDisconnected) } }
    public var recordingStopped: Bool { didSet { defaults.set(recordingStopped, forKey: Key.recordingStopped) } }
    public var linkLost: Bool { didSet { defaults.set(linkLost, forKey: Key.linkLost) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.notificationsEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        self.receiverConnected = defaults.object(forKey: Key.receiverConnected) as? Bool ?? true
        self.transmitterConnected = defaults.object(forKey: Key.transmitterConnected) as? Bool ?? true
        self.notifyOnLaunchWhenConnected = defaults.object(forKey: Key.notifyOnLaunch) as? Bool ?? false
        self.lowBattery = defaults.object(forKey: Key.lowBattery) as? Bool ?? true
        self.transmitterDisconnected = defaults.object(forKey: Key.transmitterDisconnected) as? Bool ?? true
        self.recordingStopped = defaults.object(forKey: Key.recordingStopped) as? Bool ?? true
        self.linkLost = defaults.object(forKey: Key.linkLost) as? Bool ?? true
    }

    public var snapshot: NotificationPreferences {
        NotificationPreferences(
            enabled: notificationsEnabled,
            receiverConnected: receiverConnected,
            transmitterConnected: transmitterConnected,
            notifyOnLaunchWhenConnected: notifyOnLaunchWhenConnected,
            lowBattery: lowBattery,
            transmitterDisconnected: transmitterDisconnected,
            recordingStopped: recordingStopped,
            linkLost: linkLost
        )
    }
}
