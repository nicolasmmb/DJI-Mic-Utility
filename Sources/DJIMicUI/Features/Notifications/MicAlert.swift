import Foundation

public enum MicAlert: Equatable, Sendable {
    case receiverConnected(name: String?)
    case transmitterConnected(unit: Int, name: String?, batteryGauge: Int, charging: Bool)
    case lowBattery(unit: Int, name: String?, gauge: Int)
    case transmitterDisconnected(unit: Int, name: String?)
    case recordingStopped(unit: Int, name: String?)
    case linkLost(receiverName: String?)

    var identifier: String {
        switch self {
        case .receiverConnected: "connect.rx"
        case .transmitterConnected(let unit, _, _, _): "connect.tx.\(unit)"
        case .lowBattery(let unit, _, _): "battery.tx.\(unit)"
        case .transmitterDisconnected(let unit, _): "disconnect.tx.\(unit)"
        case .recordingStopped(let unit, _): "recording.tx.\(unit)"
        case .linkLost: "link.rx"
        }
    }

    var threadIdentifier: String {
        switch self {
        case .receiverConnected: "connection.rx"
        case .transmitterConnected(let unit, _, _, _): "connection.tx.\(unit)"
        case .lowBattery(let unit, _, _): "battery.tx.\(unit)"
        case .transmitterDisconnected(let unit, _): "disconnect.tx.\(unit)"
        case .recordingStopped(let unit, _): "recording.tx.\(unit)"
        case .linkLost: "link.rx"
        }
    }
}

public enum MicNotificationAction: Equatable, Sendable {
    case reconnect
    case rerecord(unit: Int)
}

public extension NotificationPreferences {
    func allows(_ alert: MicAlert) -> Bool {
        switch alert {
        case .receiverConnected:
            receiverConnected
        case .transmitterConnected:
            transmitterConnected
        case .lowBattery:
            lowBattery
        case .transmitterDisconnected:
            transmitterDisconnected
        case .recordingStopped:
            recordingStopped
        case .linkLost:
            linkLost
        }
    }
}
