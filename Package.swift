// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TabloDB",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TabloDB", targets: ["TabloDB"])
    ],
    dependencies: [
        // Dependencies will be added here for SQLite and DuckDB
    ],
    targets: [
        .executableTarget(
            name: "TabloDB",
            dependencies: []
        )
    ]
)