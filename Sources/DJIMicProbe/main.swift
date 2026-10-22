import DJIMicProtocol
import DJIMicSession
import Foundation

let session = MicSession()
session.start()

var snapshots = session.snapshots.makeAsyncIterator()
let deadline = Date().addingTimeInterval(4)
let testCommand = CommandLine.arguments.contains("--test-command")
var didSend = false

while Date() < deadline {
    if let snapshot = await snapshots.next() {
        let rx = snapshot.receiverIdentity?.productName ?? "-"
        let tx = snapshot.sortedTransmitters.map { "TX\($0.unit) bat=\($0.batteryGauge) level=\($0.inputLevel ?? -1)" }.joined(separator: " ")
        print("connection=\(snapshot.connection) rx=\(rx) \(tx)")

        if testCommand, snapshot.connection.isConnected, !didSend {
            didSend = true
            do {
                try await session.send(.gain(snapshot.receiver?.gain ?? 0))
                print("command ACK ok")
            } catch {
                print("command failed: \(error)")
            }
        }
    }
}

session.stop()
