// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkillsManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SkillsManager", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/Kolos65/Mockable.git", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.5.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.8.1")
    ],
    targets: [
        // Domain Layer
        .target(
            name: "Domain",
            dependencies: [
                .product(name: "Mockable", package: "Mockable")
            ],
            path: "Sources/Domain",
            swiftSettings: [
                .define("MOCKING")
            ]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: [
                "Domain",
                .product(name: "Mockable", package: "Mockable")
            ],
            path: "Tests/DomainTests",
            swiftSettings: [
                .define("MOCKING")
            ]
        ),

        // Infrastructure Layer
        .target(
            name: "Infrastructure",
            dependencies: [
                "Domain",
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Mockable", package: "Mockable")
            ],
            path: "Sources/Infrastructure",
            swiftSettings: [
                .define("MOCKING")
            ]
        ),
        .testTarget(
            name: "InfrastructureTests",
            dependencies: [
                "Infrastructure",
                "Domain",
                .product(name: "Mockable", package: "Mockable")
            ],
            path: "Tests/InfrastructureTests",
            swiftSettings: [
                .define("MOCKING")
            ]
        ),

        // App Layer
        .executableTarget(
            name: "App",
            dependencies: [
                "Domain",
                "Infrastructure",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/App",
            swiftSettings: [
                .define("ENABLE_SPARKLE")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                "Domain",
                "Infrastructure",
                .product(name: "Mockable", package: "Mockable")
            ],
            path: "Tests/AppTests",
            swiftSettings: [
                .define("MOCKING")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
