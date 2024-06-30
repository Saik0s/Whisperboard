// swift-tools-version: 5.10
import PackageDescription

#if TUIST
  import ProjectDescription

  let packageSettings = PackageSettings()
#endif

let package = Package(
  name: "WhisperBoardDependencies",
  dependencies: [
    .package(url: "https://github.com/krzysztofzablocki/Inject.git", branch: "main"),

    .package(url: "https://github.com/aheze/Popovers.git", from: "1.3.2"),
    .package(url: "https://github.com/aheze/VariableBlurView.git", from: "1.0.0"),
    .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.4.3"),
    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
    .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
    .package(url: "https://github.com/dmrschmidt/DSWaveformImage.git", from: "14.2.2"),
    .package(url: "https://github.com/gohanlon/swift-memberwise-init-macro", from: "0.4.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "3.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.10.4"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-tagged.git", from: "0.10.0"),
    .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "1.0.0"),
    .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "1.0.2"),
    .package(url: "https://github.com/yannickl/DynamicColor.git", from: "5.0.1"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    .package(url: "https://github.com/Cindori/FluidGradient.git", from: "1.0.0"),
    .package(url: "https://github.com/davdroman/swiftui-navigation-transitions.git", from: "0.13.3"),
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.7.2"),
    .package(url: "https://github.com/kean/PulseLogHandler.git", from: "4.0.1"),
    .package(url: "https://github.com/EmergeTools/Pow.git", from: "1.0.4"),
  ]
)
