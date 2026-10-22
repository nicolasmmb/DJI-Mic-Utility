import Foundation

public extension ParsedFrame {
    var technicalSummary: String {
        switch content {
        case .ack(let ack):
            return "ACK seq=\(String(format: "%04x", ack.sequence)) \(ack.accepted ? "ok" : "rejected")"
        case .push(.identity(let push)):
            let rx = push.receiver?.productName ?? "-"
            let tx = push.transmitters
                .sorted { $0.key < $1.key }
                .map { "TX\($0.key)=\($0.value.productName)" }
                .joined(separator: " ")
            return "Identity RX=\(rx) \(tx)"
        case .push(.status(let push)):
            let rx = push.receiver.map { "nc=\($0.noiseCancelEnabled) gain=\($0.gain)" } ?? "-"
            let tx = push.transmitters
                .sorted { $0.key < $1.key }
                .map { "TX\($0.key) lvl=\($0.value.inputLevel ?? -1) bat=\($0.value.batteryGauge)" }
                .joined(separator: " ")
            return "Status \(rx) \(tx)"
        case .push(.level(let push)):
            let values = push.levels.sorted { $0.key < $1.key }.map { "TX\($0.key)=\($0.value)" }.joined(separator: " ")
            return "Level \(values)"
        case .push(.unknown(let type, _)):
            return "Push type=\(String(format: "%02x", type))"
        case .command(let command):
            return "Command target=\(String(format: "%04x", command.target)) id=\(String(format: "%04x", command.command))"
        case .unknown:
            return "Unknown frame"
        }
    }
}
