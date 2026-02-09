// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "dotphrase",
    products: [
        .library(name: "DotPhraseCore", targets: ["DotPhraseCore"]),
        .executable(name: "dotphrase", targets: ["DotPhraseCLI"]),
    ],
    targets: [
        .target(name: "DotPhraseCore"),
        .executableTarget(
            name: "DotPhraseCLI",
            dependencies: ["DotPhraseCore"]
        ),
    ]
)
