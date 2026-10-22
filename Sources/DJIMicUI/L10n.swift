import Foundation

public enum L10n {
    static var languageOverride: String?

    public static func s(_ key: String) -> String {
        if let languageOverride,
           let path = Bundle.module.path(forResource: languageOverride, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: s(key), arguments: arguments)
    }
}
