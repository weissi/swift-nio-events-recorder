// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-nio-events-recorder",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS("9999")
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "NIOEventsRecorder",
            targets: ["NIOEventsRecorder"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.0.0"),

    ],
    targets: [
        .target(
            name: "NIOEventsRecorderDemo",
            dependencies: ["NIOEventsRecorder",
                           .product(name: "NIO", package: "swift-nio"),
        ]),
        .target(
            name: "NIOEventsRecorder",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services")
        ]),
        .testTarget(
            name: "NIOEventsRecorderTests",
            dependencies: ["NIOEventsRecorder"]),
    ]
)
