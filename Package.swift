// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FrameCut", platforms: [.macOS("15.0"), .iOS("18.0")], products: [.library(name: "FrameCutCore", targets: ["FrameCutCore"])], targets: [.target(name: "FrameCutCore"), .testTarget(name: "FrameCutCoreTests", dependencies: ["FrameCutCore"])])
