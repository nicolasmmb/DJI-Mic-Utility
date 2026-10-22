import DJIMicSession

/// Maps session failures to user-facing localized messages.
enum SessionErrorMessage {
    static func localized(for error: Error) -> String {
        guard let sessionError = error as? MicSessionError else {
            return L10n.format("error.unknown", String(describing: error))
        }
        return sessionError.localized
    }
}

private extension MicSessionError {
    var localized: String {
        switch self {
        case .disconnected:
            L10n.s("error.disconnected")
        case .timeout:
            L10n.s("error.timeout")
        case .rejected:
            L10n.s("error.rejected")
        case .transport(let message):
            L10n.format("error.transport", message)
        }
    }
}
