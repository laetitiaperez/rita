// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Rita",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RitaCore", targets: ["RitaCore"]),
        .executable(name: "Rita", targets: ["Rita"]),
    ],
    targets: [
        .target(name: "RitaCore"),
        // L'icône sera copiée dans Rita.app par scripts/bundle.sh, pas embarquée par SwiftPM.
        .executableTarget(name: "Rita", dependencies: ["RitaCore"], exclude: ["Resources"]),
        .testTarget(
            name: "RitaCoreTests",
            dependencies: ["RitaCore"],
            resources: [.copy("Resources")]
        ),
    ]
)
