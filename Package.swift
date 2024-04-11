// swift-tools-version: 5.10
import PackageDescription

#if TUIST
  import ProjectDescription
  import ProjectDescriptionHelpers

  let packageSettings = PackageSettings(
    baseSettings: .settings(base: [
      "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
    ])
  )
#endif

let package = Package(
  name: "WhisperBoard",
  platforms: [
    .iOS(.v16),
    .macOS(.v10_15),
  ],
  dependencies: [
    .package(url: "https://github.com/aheze/Popovers.git", branch: "main"),
    .package(url: "https://github.com/aheze/VariableBlurView.git", branch: "main"),
    .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.3.3"),
    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0"),
    .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
    .package(url: "https://github.com/dmrschmidt/DSWaveformImage.git", from: "13.0.2"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "3.0.0"),
    .package(url: "https://github.com/krzysztofzablocki/Inject.git", branch: "main"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.58.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
    .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "0.6.1"),
    .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "0.5.2"),
    .package(url: "https://github.com/yannickl/DynamicColor.git", from: "5.0.1"),
  ]
)