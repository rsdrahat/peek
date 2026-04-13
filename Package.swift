// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "peek",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "peek", targets: ["peek"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "peek",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "peekTests",
            dependencies: [
                "peek",
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
    ]
)
