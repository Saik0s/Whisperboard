// swift-tools-version:5.8

// import PackageDescription
//
// let packageName = "AppKit"
//
//// Necessary for `sourcekit-lsp` support in VSCode:`
//
// let package = Package(
//  name: packageName,
//  platforms: [
//    .iOS(.v16),
//    // disable building on macOS
//    .macOS("99.0"),
//  ],
//  products: [
//    .library(name: packageName, targets: [packageName]),
//  ],
//  dependencies: [
//    .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
//    .package(url: "https://github.com/Saik0s/AppDevUtils.git", from: "0.2.1"),
//    .package(url: "https://github.com/aheze/Popovers.git", branch: "main"),
//    .package(url: "https://github.com/aheze/VariableBlurView.git", branch: "main"),
//    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0"),
//    .package(url: "https://github.com/dmrschmidt/DSWaveformImage.git", from: "11.0.0"),
//    .package(url: "https://github.com/ggerganov/whisper.spm.git", branch: "master"),
//    .package(url: "https://github.com/krzysztofzablocki/Inject.git", branch: "main"),
//    .package(url: "https://github.com/marksands/BetterCodable", branch: "master"),
//    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.58.0"),
//    .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "0.6.1"),
//    .package(url: "https://github.com/tgrapperon/swift-dependencies-additions", from: "0.5.2"),
//    .package(url: "https://github.com/yannickl/DynamicColor.git", from: "5.0.1"),
//    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
//  ],
//  targets: [
//    .target(
//      name: packageName,
//      dependencies: [
//        .byNameItem(
//          name: "Inject",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "swift-snapshot-testing",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "swift-composable-architecture",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "SwiftUI-Introspect",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "DynamicColor",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "whisper",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "DSWaveformImage",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "AudioKit",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "AppDevUtils",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "Popovers",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "VariableBlurView",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "BetterCodable",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//        .byNameItem(
//          name: "swift-dependencies-additions",
//          condition: .when(platforms: [
//            .iOS,
//          ])
//        ),
//      ],
//      path: packageName,
//      sources: [
//        "Sources",
//        "Derived",
//      ]
//    ),
//    .testTarget(
//      name: "\(packageName)Tests",
//      dependencies: [
//      ],
//      path: packageName,
//      sources: [
//        "Tests",
//      ]
//    ),
//  ]
// )
