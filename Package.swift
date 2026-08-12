// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shunt",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Explicit dependency because the Xcode Command Line Tools toolchain doesn't
        // bundle the Testing module; harmless when building with full Xcode.
        // Pinned below 6.3 — from 6.3 the package links the toolchain-only
        // _TestingInterop library, which the command line tools don't ship.
        .package(url: "https://github.com/swiftlang/swift-testing.git", "6.2.0"..<"6.3.0"),
    ],
    targets: [
        .target(name: "ShuntCore", path: "Sources/ShuntCore"),
        .executableTarget(name: "Shunt", dependencies: ["ShuntCore"], path: "Sources/Shunt"),
        // A plain executable rather than a testTarget so tests can run with just the
        // command line tools, whose `swift test` harness lacks XCTest/Testing support.
        .executableTarget(
            name: "shunt-tests",
            dependencies: ["ShuntCore", .product(name: "Testing", package: "swift-testing")],
            path: "Tests/ShuntTests"
        ),
    ]
)
