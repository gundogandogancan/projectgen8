// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "a19consumer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "/Users/dogancangundogan/PROJECTGEN8/Gen8/packages/GuardianKit")
    ],
    targets: [
        .executableTarget(
            name: "a19consumer",
            dependencies: [.product(name: "GuardianCore", package: "GuardianKit")]
        )
    ]
)
