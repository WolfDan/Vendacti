// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let exampleDependencies: [Target.Dependency] = [
    .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
    .product(name: "DefaultBackend", package: "swift-cross-ui"),
    .product(name: "Vendacti", package: "Vendacti"),
]

let package = Package(
    name: "BarExample",
    dependencies: [
        .package(name: "Vendacti", path: ".."),
        .package(url: "https://github.com/WolfDan/swift-cross-ui", branch: "scene-integration"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "BarExample",
            dependencies: exampleDependencies,
        )
    ]
)
