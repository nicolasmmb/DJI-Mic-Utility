import DJIMicProtocol

extension DeviceSnapshot {
    /// Display name for the receiver, matching DJI's own app: the series label
    /// plus the radio suffix. The identity frame's `productName` is not used
    /// here because the receiver reports the kit name (for example
    /// "DJI Mic Mini 2") even when paired with DJI Mic 2 transmitters.
    var receiverDisplayName: String {
        guard let identity = receiverIdentity ?? primaryIdentity else {
            return L10n.s("menu.noDevice")
        }
        return Self.composedName(L10n.s("device.rxSeries"), suffix: identity.addressSuffix)
    }

    /// Display name for a transmitter card: reported model plus suffix, while
    /// the card title already carries the unit number.
    func transmitterDisplayName(unit: Int) -> String? {
        guard let identity = transmitterIdentities[unit] else { return nil }
        return Self.composedName(identity.productName, suffix: identity.addressSuffix)
    }

    /// Full transmitter name used by the diagnostics window, including the
    /// unit number like DJI's app: "DJI Mic 2 TX1–85f8c8".
    func transmitterDiagnosticName(unit: Int) -> String? {
        guard let identity = transmitterIdentities[unit] else { return nil }
        let base = "\(identity.productName) TX\(unit)"
        return Self.composedName(base, suffix: identity.addressSuffix)
    }

    private static func composedName(_ base: String, suffix: String) -> String {
        suffix.isEmpty ? base : "\(base)–\(suffix)"
    }
}
