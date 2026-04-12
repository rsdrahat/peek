// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rview",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "rview", targets: ["rview"]),
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "rview",
            dependencies: ["Ink"],
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "rviewTests", dependencies: ["rview"]),
    ]
)
