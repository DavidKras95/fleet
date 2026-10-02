// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fleet",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Fleet",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Fleet",
            swiftSettings: [
                // Tells the OS to look in Contents/Frameworks at runtime so
                // Sparkle.framework is found after we embed it in the app bundle.
                .unsafeFlags(["-Xlinker", "-rpath",
                              "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "FleetTests",
            dependencies: ["Fleet"],
            path: "Tests/FleetTests"
        ),
    ]
)
