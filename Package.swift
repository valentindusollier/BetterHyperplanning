// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BetterHyperplanning",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", Version("0.0.0") ..< Version("2.0.0")),
        .package(url: "https://github.com/valentindusollier/iCalKit.git", from: "0.0.2"),
        .package(name: "PerfectHTTPServer", url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "BetterHyperplanning",
            dependencies: [
                "iCalKit",
                "PerfectHTTPServer",
                //"Logging",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "BetterHyperplanningTests",
            dependencies: ["BetterHyperplanning"]),
    ]
)
