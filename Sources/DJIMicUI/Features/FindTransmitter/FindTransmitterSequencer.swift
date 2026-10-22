import DJIMicProtocol

/// Blinks one transmitter's LED so the user can identify the physical unit.
///
/// The mic LED command is a persistent toggle, not a momentary blink, so the
/// state captured before the animation is always written back: on completion,
/// on cancellation and after a rejected command.
struct FindTransmitterSequencer {
    let unit: Int
    let blinks: Int
    let interval: Duration
    let send: (MicSetting) async throws -> Void

    func run(originallyOff: Bool) async throws {
        var failure: Error?

        do {
            try await blink()
        } catch is CancellationError {
            // The restore below still has to run.
        } catch {
            failure = error
        }

        do {
            try await restore(originallyOff: originallyOff)
        } catch is CancellationError {
            // `send` does not observe cancellation, so the command was
            // already sent; nothing else to recover here.
        } catch {
            failure = failure ?? error
        }

        if let failure {
            throw failure
        }
    }

    private func blink() async throws {
        for _ in 0..<max(1, blinks) {
            try Task.checkCancellation()
            try await send(.micLED(true, unit: unit))
            try await Task.sleep(for: interval)

            try Task.checkCancellation()
            try await send(.micLED(false, unit: unit))
            try await Task.sleep(for: interval)
        }
    }

    private func restore(originallyOff: Bool) async throws {
        try await send(.micLED(!originallyOff, unit: unit))
    }
}
