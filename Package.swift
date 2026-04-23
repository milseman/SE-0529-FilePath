// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SE-0529-FilePath",
    products: [
        .library(name: "FilePath", targets: ["FilePath"]),
        .executable(name: "filepath-play", targets: ["filepath-play"]),
    ],
    targets: [
        .target(name: "FilePath"),
        .executableTarget(
            name: "filepath-play",
            dependencies: ["FilePath"]
        ),
        .testTarget(
            name: "FilePathTests",
            dependencies: ["FilePath"]
        ),
    ]
)
