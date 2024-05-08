// swift-tools-version: 5.10
import PackageDescription

#if TUIST
  import ProjectDescription

  let packageSettings = PackageSettings(
    productTypes: [
      "AsyncAlgorithms": .framework,
      "AudioKit": .framework,
      "ComposableArchitecture": .framework,
      "DependenciesAdditions": .framework,
      "DSWaveformImage": .framework,
      "DSWaveformImageViews": .framework,
      "DynamicColor": .framework,
      "Inject": .framework,
      "KeychainAccess": .framework,
      "Logging": .framework,
      "Lottie": .framework,
      "Popovers": .framework,
      "SwiftUIIntrospect": .framework,
      "VariableBlurView": .framework,
      "FluidGradient": .framework,
      "NavigationTransitions": .framework,
      "CombineSchedulers": .framework,
      "Clocks": .framework,
      "OrderedCollections": .framework,
      "Dependencies": .framework,
      "XCTestDynamicOverlay": .framework,
      "ConcurrencyExtras": .framework,
      "_CollectionsUtilities": .framework,
    ],
    baseSettings: .settings(base: [
      "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
    ])
  )
#endif

let package = Package(
  name: "WhisperBoardDependencies",
  dependencies: [
    .package(url: "https://github.com/krzysztofzablocki/Inject.git", branch: "main"),

    .package(url: "https://github.com/aheze/Popovers.git", branch: "main"),
    .package(url: "https://github.com/aheze/VariableBlurView.git", branch: "main"),
    .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.3.3"),
    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0"),
    .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
    .package(url: "https://github.com/dmrschmidt/DSWaveformImage.git", from: "13.0.2"),
    .package(url: "https://github.com/gohanlon/swift-memberwise-init-macro", from: "0.4.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "3.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.10.2"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-tagged.git", from: "0.10.0"),
    .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "1.0.0"),
    .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "1.0.1"),
    .package(url: "https://github.com/yannickl/DynamicColor.git", from: "5.0.1"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    .package(url: "https://github.com/Cindori/FluidGradient.git", from: "1.0.0"),
    .package(url: "https://github.com/davdroman/swiftui-navigation-transitions.git", from: "0.13.3"),
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.6.1"),
  ]
)
