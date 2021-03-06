// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MadDrivers",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MadDrivers",
            targets: [
                "LCD1602",
                "LIS3DH",
                "MCP4725",
                "SHT3x",
                "ST7789",
                "VEML6040"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/madmachineio/SwiftIO.git", from: "0.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LCD1602",
            dependencies: ["SwiftIO"]),
        .target(
            name: "LIS3DH",
            dependencies: ["SwiftIO"]),
        .target(
            name: "MCP4725",
            dependencies: ["SwiftIO"]),
        .target(
            name: "SHT3x",
            dependencies: ["SwiftIO"]),
        .target(
            name: "ST7789",
            dependencies: ["SwiftIO"]),
        .target(
            name: "VEML6040",
            dependencies: ["SwiftIO"]),
    ]
)
