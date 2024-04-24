import Foundation
import ProjectDescription
import ProjectDescriptionHelpers

let projectSettings: SettingsDictionary = [
  "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
  "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
  "CODE_SIGN_STYLE": "Automatic",
  "DEVELOPMENT_TEAM": SettingValue(stringLiteral: devTeam),
  "IPHONEOS_DEPLOYMENT_TARGET": SettingValue(stringLiteral: deploymentTargetString),
  "ENABLE_BITCODE": "NO",
  "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
]

let debugSettings: SettingsDictionary = [
  "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -enable-actor-data-race-checks",
  "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Support/Bridging.h",
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS": Environment.isAppStore.getBoolean(default: false) ? "APPSTORE DEBUG" : "DEBUG",
]

let releaseSettings: SettingsDictionary = [
  "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Support/Bridging.h",
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS": Environment.isAppStore.getBoolean(default: false) ? "APPSTORE" : "",
]

let project = Project(
  name: "WhisperBoardKit",

  options: .options(
    disableShowEnvironmentVarsInScriptPhases: true,
    textSettings: .textSettings(
      indentWidth: 2,
      tabWidth: 2
    )
  ),

  packages: [
    .package(url: "https://github.com/ggerganov/whisper.cpp.git", .branch("master")),
    .package(url: "https://github.com/rollbar/rollbar-apple", from: "3.2.0"),
  ],

  targets: [
    .target(
      name: "WhisperBoardKit",
      destinations: appDestinations,
      product: .framework,
      bundleId: "me.igortarasenko.WhisperboardKit",
      deploymentTargets: appDeploymentTargets,
      infoPlist: .extendingDefault(with: [:]),
      sources: "Sources/**",
      resources: "Resources/**",
      dependencies: [
        .sdk(name: "c++", type: .library, status: .required),
        .sdk(name: "CloudKit", type: .framework, status: .optional),
        // .sdk(name: "StoreKit", type: .framework, status: .optional),

        .external(name: "AsyncAlgorithms"),
        .external(name: "AudioKit"),
        .external(name: "ComposableArchitecture"),
        .external(name: "DSWaveformImage"),
        .external(name: "DSWaveformImageViews"),
        .external(name: "DependenciesAdditions"),
        .external(name: "DynamicColor"),
        .external(name: "Inject"),
        .external(name: "KeychainAccess"),
        .external(name: "Popovers"),
        // .external(name: "RevenueCat"),
        .external(name: "SwiftUIIntrospect"),
        .external(name: "VariableBlurView"),
        .external(name: "Lottie"),

        // .external(name: "whisper"),
        .package(product: "whisper"),
        .package(product: "RollbarNotifier"),
      ],
      settings: .settings(
        base: projectSettings,
        debug: debugSettings,
        release: releaseSettings,
        defaultSettings: .recommended
      )
    ),
    .target(
      name: "WhisperBoardKitTests",
      destinations: appDestinations,
      product: .unitTests,
      bundleId: "me.igortarasenko.WhisperboardKitTests",
      infoPlist: .default,
      sources: "Tests/**",
      dependencies: [
        .target(name: "WhisperBoardKit"),
        .external(name: "SnapshotTesting"),
      ],
      settings: .settings(
        base: [
          "CODE_SIGN_IDENTITY": "",
          "CODE_SIGNING_REQUIRED": "NO",
        ]
      )
    ),
  ],

  resourceSynthesizers: [
    .files(extensions: ["bin"]),
    .assets(),
    .fonts(),
    .strings(),
    .custom(
      name: "Lottie",
      parser: .json,
      extensions: ["lottie"]
    ),
  ]
)
