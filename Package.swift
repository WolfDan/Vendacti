// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Vendacti",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Vendacti",
            targets: ["Vendacti"])
    ],
    dependencies: [
        .package(url: "https://github.com/WolfDan/swift-cross-ui", branch: "scene-integration"),
        .package(url: "https://github.com/WolfDan/SwiftGtk4LayerShell", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Vendacti",
            dependencies: [
                .product(name: "Gtk", package: "swift-cross-ui"),
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "GtkBackend", package: "swift-cross-ui"),
                .product(name: "Gtk4LayerShell", package: "SwiftGtk4LayerShell"),
            ]),
        .testTarget(
            name: "VendactiTests",
            dependencies: [
                "Vendacti",
                .product(name: "Gtk", package: "swift-cross-ui"),
                .product(name: "Gtk4LayerShell", package: "SwiftGtk4LayerShell"),
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "GtkBackend", package: "swift-cross-ui"),
            ]
        ),
    ]
)
