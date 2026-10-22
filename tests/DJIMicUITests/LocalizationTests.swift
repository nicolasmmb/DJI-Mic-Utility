import Foundation
import Testing
@testable import DJIMicUI

private func keys(in url: URL) throws -> Set<String> {
    let content = try String(contentsOf: url, encoding: .utf8)
    var result = Set<String>()
    for line in content.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/*"), !trimmed.hasPrefix("//") else { continue }
        guard let separator = trimmed.firstIndex(of: "=") else { continue }
        let key = trimmed[..<separator]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        if !key.isEmpty {
            result.insert(key)
        }
    }
    return result
}

@Test func localizationKeysAreComplete() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let resources = root.appendingPathComponent("Sources/DJIMicUI/Resources")
    let english = try keys(in: resources.appendingPathComponent("en.lproj/Localizable.strings"))
    let portuguese = try keys(in: resources.appendingPathComponent("pt-BR.lproj/Localizable.strings"))

    #expect(!english.isEmpty)
    #expect(english == portuguese, "en and pt-BR keys differ")
}

@Test func localizationBundleLoads() {
    let value = L10n.s("app.name")
    #expect(!value.isEmpty)
    #expect(value != "app.name")
}
