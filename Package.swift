// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SurfaceDrawingEditor",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SurfaceDrawingEditor", targets: ["SurfaceDrawingEditor"])
    ],
    targets: [
        .target(
            name: "SurfaceDrawingEditor",
            path: "Sources/SurfaceDrawingEditor",
            resources: [
                .process("Resources")  // шрифты и ассеты
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
