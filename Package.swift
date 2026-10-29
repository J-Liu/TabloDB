// swift-tools-version: 5.9

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import PackageDescription

let package = Package(
    name: "TabloDB",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TabloDB", targets: ["TabloDB"])
    ],
    dependencies: [
        .package(url: "https://github.com/duckdb/duckdb-swift", from: "1.1.3"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "TabloDB",
            dependencies: [
                .product(name: "DuckDB", package: "duckdb-swift"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
