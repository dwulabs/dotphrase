// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "dotphrase",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DotPhraseCore", targets: ["DotPhraseCore"]),
        .executable(name: "dotphrase", targets: ["DotPhraseCLI"]),
        .executable(name: "dotphrase-menubar", targets: ["DotPhraseApp"]),
    ],
    targets: [
        .target(name: "DotPhraseCore"),
        .executableTarget(
            name: "DotPhraseCLI",
            dependencies: ["DotPhraseCore"]
        ),
        .executableTarget(
            name: "DotPhraseApp",
            dependencies: ["DotPhraseCore"]
        ),
    ]
)
