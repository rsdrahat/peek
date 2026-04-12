// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rview",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "rview", targets: ["rview"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "rview",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "rviewTests",
            dependencies: [
                "rview",
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
    ]
)
