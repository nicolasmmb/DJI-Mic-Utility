import Foundation

public enum L10n {
    public static func s(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: s(key), arguments: arguments)
    }
}
