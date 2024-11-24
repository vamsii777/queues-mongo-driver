// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "queues-mongo-driver",
    platforms: [
        .macOS(.v13),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "QueuesMongoDriver", targets: ["QueuesMongoDriver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
        .package(url: "https://github.com/vamsii777/queues.git", from: "2.0.0-beta.1"),
        .package(url: "https://github.com/OpenKitten/MongoKitten.git", from: "7.9.5")
    ],
    targets: [
        .target(
            name: "QueuesMongoDriver",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Queues", package: "queues"),
                .product(name: "MongoKitten", package: "MongoKitten"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "QueuesMongoDriverTests",
            dependencies: [
                .target(name: "QueuesMongoDriver"),
                .product(name: "XCTVapor", package: "vapor")
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency=complete"),
] }
