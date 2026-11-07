// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Tapis", platforms: [.iOS(.v16), .macOS(.v13)], products: [.library(name: "TapisCore", targets: ["TapisCore"])], targets: [.target(name: "TapisCore"), .testTarget(name: "TapisCoreTests", dependencies: ["TapisCore"])])
