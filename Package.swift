// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DJIMicControl",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "DJIMicProtocol", targets: ["DJIMicProtocol"]),
        .library(name: "DJIMicTransport", targets: ["DJIMicTransport"]),
        .library(name: "DJIMicSession", targets: ["DJIMicSession"]),
        .library(name: "DJIMicUI", targets: ["DJIMicUI"]),
        .executable(name: "DJIMicApp", targets: ["DJIMicApp"]),
        .executable(name: "djimic-swift-probe", targets: ["DJIMicProbe"]),
    ],
    targets: [
        .target(
            name: "DJIMicUSB",
            path: "Sources/DJIMicUSB",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .target(name: "DJIMicProtocol"),
        .target(
            name: "DJIMicTransport",
            dependencies: ["DJIMicUSB"],
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .target(
            name: "DJIMicSession",
            dependencies: ["DJIMicProtocol", "DJIMicTransport"]
        ),
        .target(
            name: "DJIMicUI",
            dependencies: ["DJIMicProtocol", "DJIMicSession"],
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "DJIMicApp",
            dependencies: ["DJIMicProtocol", "DJIMicSession", "DJIMicUI"]
        ),
        .executableTarget(
            name: "DJIMicProbe",
            dependencies: ["DJIMicProtocol", "DJIMicTransport", "DJIMicSession"]
        ),
        .testTarget(
            name: "DJIMicProtocolTests",
            dependencies: ["DJIMicProtocol"],
            path: "tests/DJIMicProtocolTests"
        ),
        .testTarget(
            name: "DJIMicSessionTests",
            dependencies: ["DJIMicProtocol", "DJIMicSession", "DJIMicTransport"],
            path: "tests/DJIMicSessionTests"
        ),
        .testTarget(
            name: "DJIMicUITests",
            dependencies: ["DJIMicUI"],
            path: "tests/DJIMicUITests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
