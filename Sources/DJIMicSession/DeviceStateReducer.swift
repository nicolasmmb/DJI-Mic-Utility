import DJIMicProtocol

/// Folds decoded push frames into the consolidated device snapshot.
///
/// Kept separate from `MicSession` so transport, acknowledgements and state
/// merging each have a single responsibility.
struct DeviceStateReducer {
    func apply(_ content: FrameContent, to state: inout DeviceSnapshot) {
        switch content {
        case .push(.identity(let push)):
            applyIdentity(push, to: &state)
        case .push(.status(let push)):
            applyStatus(push, to: &state)
        case .push(.level(let push)):
            applyLevel(push, to: &state)
        case .push(.unknown), .ack, .command, .unknown:
            break
        }
    }

    private func applyIdentity(_ push: IdentityPush, to state: inout DeviceSnapshot) {
        if let receiver = push.receiver {
            state.receiverIdentity = receiver
        }
        for (unit, identity) in push.transmitters {
            state.transmitterIdentities[unit] = identity
        }
    }

    private func applyStatus(_ push: StatusPush, to state: inout DeviceSnapshot) {
        state.receiver = push.receiver

        // Status pushes omit the live input level; keep the last value from
        // the dedicated level pushes.
        let existingTransmitters = state.transmitters
        state.transmitters = push.transmitters.mapValues { transmitter in
            var updated = transmitter
            updated.inputLevel = existingTransmitters[transmitter.unit]?.inputLevel
            return updated
        }
    }

    private func applyLevel(_ push: LevelPush, to state: inout DeviceSnapshot) {
        for (unit, level) in push.levels {
            state.transmitters[unit]?.inputLevel = level
        }
    }
}
