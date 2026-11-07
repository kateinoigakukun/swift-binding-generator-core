// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-binding-generator-core",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "SwiftExtract",
      targets: ["SwiftExtract"]
    ),

    .library(
      name: "SwiftExtractConfigurationShared",
      targets: ["SwiftExtractConfigurationShared"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", "0.4.0"..<"0.5.0", traits: ["SubprocessFoundation"]),
  ],
  targets: [
    .target(
      name: "SwiftExtractConfigurationShared"
    ),

    .target(
      name: "SwiftExtract",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftIfConfig", package: "swift-syntax"),
        .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        "SwiftExtractConfigurationShared",
      ],
      path: "Sources/SwiftExtract",
      resources: [
        // Holds the `dummy.json` placeholder so SwiftPM emits a `Bundle.module`
        // for this target. The real `static-build-config.json` is generated at
        // build time by the `_StaticBuildConfigPlugin` build tool below.
        .process("Resources")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        .plugin(name: "_StaticBuildConfigPlugin")
      ]
    ),

    .executableTarget(
      name: "StaticBuildConfigPluginExecutable",
      dependencies: [
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "SwiftIfConfig", package: "swift-syntax"),
      ]
    ),

    .plugin(
      name: "_StaticBuildConfigPlugin",
      capability: .buildTool(),
      dependencies: [
        "StaticBuildConfigPluginExecutable"
      ]
    ),

    .testTarget(
      name: "SwiftExtractTests",
      dependencies: [
        "SwiftExtract",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]
    ),
  ]
)
