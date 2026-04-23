// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SE-0529-FilePath",
    products: [
        .library(name: "FilePath", targets: ["FilePath"]),
    ],
    targets: [
        .target(name: "FilePath"),
        .testTarget(
            name: "FilePathTests",
            dependencies: ["FilePath"]
        ),
    ]
)
