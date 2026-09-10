// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "ReactiveSwift",
    platforms: [
        .macOS(.v10_13), .iOS(.v11), .tvOS(.v11), .watchOS(.v4)
    ],
    products: [
        .library(name: "ReactiveSwift", targets: ["ReactiveSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", from: "4.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "9.0.0"),
    ],
    targets: [
        .target(name: "ReactiveSwift", dependencies: [], path: "Sources"),
        .testTarget(name: "ReactiveSwiftTests", dependencies: ["ReactiveSwift", "Quick", "Nimble"]),
    ],
    swiftLanguageVersions: [.v5]
)
