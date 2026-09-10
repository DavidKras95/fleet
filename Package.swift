// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fleet",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "Fleet",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            path: "Sources/Fleet"
        ),
        .testTarget(
            name: "FleetTests",
            dependencies: ["Fleet"],
            path: "Tests/FleetTests"
        ),
    ]
)
