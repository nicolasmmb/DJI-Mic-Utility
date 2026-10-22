import DJIMicProtocol

/// Optimistic state updates so controls react on the same frame as the click.
///
/// Device status pushes reconcile the value almost immediately, and a rejected
/// command naturally reverts on the next push.
extension DeviceSnapshot {
    mutating func applyOptimistic(_ setting: MicSetting) {
        switch setting {
        case .gain(let value):
            receiver?.gain = value
        case .monitoringGain(let value):
            receiver?.monitoringGain = value
        case .safetyTrack(let value):
            receiver?.safetyTrack = value
        case .stereo(let value):
            receiver?.stereo = value
        case .lowCut(let value):
            updateAllTransmitters { $0.lowCut = value }
        case .micLED(let enabled, let unit):
            let ledsOff = !enabled
            switch unit {
            case .some(let unit):
                transmitters[unit]?.ledsOff = ledsOff
            case .none:
                updateAllTransmitters { $0.ledsOff = ledsOff }
            }
        case .voiceTone(let tone, let unit):
            transmitters[unit]?.voiceTone = tone
        case .mute(let muted, let unit):
            transmitters[unit]?.isMuted = muted
        case .recording(let recording, let unit):
            transmitters[unit]?.isRecording = recording
        case .vibration(let enabled):
            updateAllTransmitters { $0.vibrationEnabled = enabled }
        case .float32Recording(let enabled):
            updateAllTransmitters { $0.float32Recording = enabled }
        case .recStopLock(let enabled):
            updateAllTransmitters { $0.recStopLock = enabled }
        case .startupAutoRecording(let enabled):
            updateAllTransmitters { $0.startupAutoRecording = enabled }
        case .clippingControl(let value):
            receiver?.clippingControl = value
            updateAllTransmitters { $0.clippingControl = value }
        case .autoOffTX(let value):
            updateAllTransmitters { $0.autoOff = value }
        case .autoOffRX(let value):
            receiver?.autoOff = value
        }
    }

    /// Returns `true` when a device status push already carries the value of
    /// `setting`, so the optimistic overlay can be dropped.
    func reflects(_ setting: MicSetting) -> Bool {
        switch setting {
        case .gain(let value):
            return receiver?.gain == value
        case .monitoringGain(let value):
            return receiver?.monitoringGain == value
        case .safetyTrack(let value):
            return receiver?.safetyTrack == value
        case .stereo(let value):
            return receiver?.stereo == value
        case .lowCut(let value):
            return transmitters.values.allSatisfy { $0.lowCut == value }
        case .micLED(let enabled, let unit):
            let ledsOff = !enabled
            switch unit {
            case .some(let unit):
                return transmitters[unit]?.ledsOff == ledsOff
            case .none:
                return transmitters.values.allSatisfy { $0.ledsOff == ledsOff }
            }
        case .voiceTone(let tone, let unit):
            return transmitters[unit]?.voiceTone == tone
        case .mute(let muted, let unit):
            return transmitters[unit]?.isMuted == muted
        case .recording(let recording, let unit):
            return transmitters[unit]?.isRecording == recording
        case .vibration(let enabled):
            return transmitters.values.allSatisfy { $0.vibrationEnabled == enabled }
        case .float32Recording(let enabled):
            return transmitters.values.allSatisfy { $0.float32Recording == enabled }
        case .recStopLock(let enabled):
            return transmitters.values.allSatisfy { $0.recStopLock == enabled }
        case .startupAutoRecording(let enabled):
            return transmitters.values.allSatisfy { $0.startupAutoRecording == enabled }
        case .clippingControl(let value):
            return receiver?.clippingControl == value
        case .autoOffTX(let value):
            return transmitters.values.allSatisfy { $0.autoOff == value }
        case .autoOffRX(let value):
            return receiver?.autoOff == value
        }
    }

    private mutating func updateAllTransmitters(_ update: (inout TransmitterState) -> Void) {
        for unit in Array(transmitters.keys) {
            guard var transmitter = transmitters[unit] else { continue }
            update(&transmitter)
            transmitters[unit] = transmitter
        }
    }
}
