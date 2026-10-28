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
        // DuckDB dependency temporarily disabled due to network timeout
        // .package(url: "https://github.com/duckdb/duckdb-swift", from: "1.1.3")
    ],
    targets: [
        .executableTarget(
            name: "TabloDB",
            dependencies: [
                // .product(name: "DuckDB", package: "duckdb-swift")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)