// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MLXAI",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MLXAIKit", targets: ["MLXAIKit"]),
        .executable(name: "MLXAI", targets: ["MLXAI"]),
        .executable(name: "mlx-ai", targets: ["mlx-ai"]),
    ],
    targets: [
        .target(name: "MLXAIKit"),
        .executableTarget(name: "MLXAI", dependencies: ["MLXAIKit"]),
        .executableTarget(name: "mlx-ai", dependencies: ["MLXAIKit"]),
        .testTarget(name: "MLXAIKitTests", dependencies: ["MLXAIKit"]),
    ]
)
