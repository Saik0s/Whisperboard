import ProjectDescription

let packages: [Package] = [
  .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
  .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "4.25.8"),
  .package(url: "https://github.com/Saik0s/AppDevUtils.git", from: "0.2.1"),
  .package(url: "https://github.com/aheze/Popovers.git", .branch("main")),
  .package(url: "https://github.com/aheze/VariableBlurView.git", .branch("main")),
  .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0"),
  .package(url: "https://github.com/dmrschmidt/DSWaveformImage.git", from: "11.0.0"),
  .package(url: "https://github.com/ggerganov/whisper.spm.git", .branch("master")),
  .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "3.0.0"),
  .package(url: "https://github.com/krzysztofzablocki/Inject.git", .branch("main")),
  .package(url: "https://github.com/marksands/BetterCodable", .branch("master")),
  .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.58.0"),
  .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
  .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "0.6.1"),
  .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "0.5.2"),
  .package(url: "https://github.com/yannickl/DynamicColor.git", from: "5.0.1"),
]

let dependencies = Dependencies(
  swiftPackageManager: SwiftPackageManagerDependencies(
    packages,
    // productTypes: ["AppDevUtils": .framework],
    targetSettings: [
      "whisper": [
        "OTHER_CFLAGS": "-O3 -DNDEBUG -DGGML_USE_ACCELERATE -DWHISPER_COREML_ALLOW_FALLBACK -DWHISPER_USE_COREML $(inherited)",
        "OTHER_LDFLAGS": "-lc++ $(inherited)",
      ],
    ]
  ),
  platforms: [.iOS]
)
