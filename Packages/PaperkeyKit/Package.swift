// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PaperkeyKit",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PaperkeyKit",
            targets: ["PaperkeyKit"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CPaperkey",
            dependencies: [],
            exclude: [
                "./COPYING",
                "./CMakeLists.txt",
                "./README",
                "./paperkeytest.c"
            ],
            sources: [
                "./extract.c",
                "./output.c",
                "./packets.c",
                "./parse.c",
                "./restore.c",
                "./sha1.c",
                "./stream.c"
            ],
            cSettings: [
                .headerSearchPath("./")
            ]
        ),
        .target(
            name: "PaperkeyKit",
            dependencies: ["CPaperkey"]
        ),
        .testTarget(
            name: "PaperkeyKitTests",
            dependencies: ["PaperkeyKit"],
            resources: [
                .copy("checks")
            ]
        )
    ],
)
