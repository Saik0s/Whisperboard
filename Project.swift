import Foundation
import ProjectDescription

public let version = "1.12.1"

public let deploymentTargetString = "16.0"
public let appDeploymentTargets: DeploymentTargets = .iOS(deploymentTargetString)
public let appDestinations: Destinations = [.iPhone, .iPad]
public let devTeam = "8A76N862C8"

let isAppStore = Environment.isAppStore.getBoolean(default: false)
let isDev = Environment.isDev.getBoolean(default: false) && !isAppStore
let additionalCondition = isAppStore ? "APPSTORE" : isDev ? "DEV" : ""

let isRevealSupported = FileManager.default.fileExists(atPath: "App/Support/Reveal/RevealServer.xcframework") && !isAppStore
print("RevealServer.xcframework is \(isRevealSupported ? "supported" : "not supported")")

var appInfoPlist: [String: Plist.Value] = [
  "CFBundleShortVersionString": Plist.Value(stringLiteral: version),
  "CFBundleURLTypes": [
    [
      "CFBundleTypeRole": "Editor",
      "CFBundleURLName": .string("WhisperBoard"),
      "CFBundleURLSchemes": [
        .string("whisperboard"),
      ],
    ],
  ],
  "UIApplicationSceneManifest": [
    "UIApplicationSupportsMultipleScenes": false,
    "UISceneConfigurations": [],
  ],
  "ITSAppUsesNonExemptEncryption": false,
  "UILaunchScreen": [
    "UILaunchScreen": [:],
  ],
  "UISupportedInterfaceOrientations": [
    "UIInterfaceOrientationPortrait",
  ],
  "UISupportedInterfaceOrientations~ipad": [
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationPortraitUpsideDown",
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
  ],
  "NSMicrophoneUsageDescription": "WhisperBoard uses the microphone to record voice and later transcribe it.",
  "UIUserInterfaceStyle": "Dark",
  "UIBackgroundModes": [
    "audio",
    "processing",
  ],
  "BGTaskSchedulerPermittedIdentifiers": [
    "$(PRODUCT_BUNDLE_IDENTIFIER)",
  ],
  "NSUbiquitousContainers": [
    "iCloud.me.igortarasenko.whisperboard": [
      "NSUbiquitousContainerIsDocumentScopePublic": true,
      "NSUbiquitousContainerName": "WhisperBoard",
      "NSUbiquitousContainerSupportedFolderLevels": "Any",
    ],
  ],
]

if isDev {
  appInfoPlist["NSLocalNetworkUsageDescription"] = Plist.Value.string("Network usage required for debugging purposes")
  appInfoPlist["NSBonjourServices"] = [Plist.Value.string("_pulse._tcp")]
}

func createAppTarget(suffix: String = "", scripts: [TargetScript] = [], dependencies: [TargetDependency] = []) -> Target {
  .target(
    name: "WhisperBoard" + suffix,
    destinations: appDestinations,
    product: .app,
    bundleId: "me.igortarasenko.Whisperboard" + suffix,
    deploymentTargets: appDeploymentTargets,
    infoPlist: .extendingDefault(with: appInfoPlist),
    sources: "App/Sources/**",
    resources: .resources(
      ["App/Resources/**"],
      privacyManifest: .privacyManifest(
        tracking: false,
        trackingDomains: [],
        collectedDataTypes: [
          [
            "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeName",
            "NSPrivacyCollectedDataTypeLinked": false,
            "NSPrivacyCollectedDataTypeTracking": false,
            "NSPrivacyCollectedDataTypePurposes": [
              "NSPrivacyCollectedDataTypePurposeAppFunctionality",
            ],
          ],
        ],
        accessedApiTypes: [
          [
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": [
              "CA92.1",
            ],
          ],
        ]
      )
    ),
    entitlements: "App/Support/app.entitlements",
    scripts: scripts,

    dependencies: [
      .target(name: "ShareExtension"),
      .target(name: "WhisperBoardKit"),
    ] + dependencies,

    settings: .settings(
      base: [
        "CODE_SIGN_STYLE": "Automatic",
        "MARKETING_VERSION": SettingValue(stringLiteral: version),
        "CODE_SIGN_IDENTITY": "iPhone Developer",
        "CODE_SIGNING_REQUIRED": "YES",
      ]
    )
  )
}

let project = Project(
  name: "WhisperBoard",

  options: .options(
    disableShowEnvironmentVarsInScriptPhases: true,
    textSettings: .textSettings(
      indentWidth: 2,
      tabWidth: 2
    )
  ),

  packages: [.package(url: "https://github.com/ggerganov/whisper.cpp.git", .branch("master"))]
    + (isAppStore ? [.package(url: "https://github.com/rollbar/rollbar-apple", from: "3.2.0")] : [])
    + (isDev ? [.package(url: "https://github.com/EmergeTools/ETTrace.git", from: "1.0.0")] : []),

  settings: .settings(
    base: [
      "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
      "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
      "IPHONEOS_DEPLOYMENT_TARGET": SettingValue(stringLiteral: deploymentTargetString),
      "ENABLE_BITCODE": "NO",
      "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
      "CODE_SIGN_IDENTITY": "",
      "CODE_SIGNING_REQUIRED": "NO",
      "DEVELOPMENT_TEAM": SettingValue(stringLiteral: devTeam),
    ],
    debug: isDev
      ? [
        "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -debug-time-expression-type-checking -Xfrontend -enable-actor-data-race-checks",
        "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
      ]
      : [:]
  ),

  targets:

  // MARK: - App

  (isAppStore
    ? [
      createAppTarget(suffix: "", scripts: [], dependencies: []),
    ]
    : isDev
      ? [
        createAppTarget(
          suffix: "Dev",
          scripts:
          [
            .post(
              path: "ci_scripts/post_build_checks.sh",
              name: "Additional Checks",
              basedOnDependencyAnalysis: false
            ),
            .post(
              script: """
              export REVEAL_SERVER_FILENAME="RevealServer.xcframework"
              export REVEAL_SERVER_PATH="${SRCROOT}/App/Support/Reveal/${REVEAL_SERVER_FILENAME}"
              [ -d "${REVEAL_SERVER_PATH}" ] && "${REVEAL_SERVER_PATH}/Scripts/integrate_revealserver.sh" || echo "Reveal Server not loaded into ${TARGET_NAME}: ${REVEAL_SERVER_FILENAME} could not be found."
              """,
              name: "Reveal Server",
              basedOnDependencyAnalysis: false
            ),
            .post(
              script: "xclogparser parse --workspace WhisperBoard.xcworkspace --reporter html || true",
              name: "XCLogParser",
              basedOnDependencyAnalysis: false
            ),
          ],
          dependencies: [.package(product: "ETTrace")]
            // Check if RevealServer framework exists at this path and only then include it in this array of dependencies
            + (isRevealSupported ? [.xcframework(path: "//App/Support/Reveal/RevealServer.xcframework", status: .optional)] : [])
        ),
      ]
      : [
        createAppTarget(suffix: "", scripts: [], dependencies: []),
      ]) + [
    // MARK: - ShareExtension

    .target(
      name: "ShareExtension",
      destinations: appDestinations,
      product: .appExtension,
      bundleId: "me.igortarasenko.Whisperboard.ShareExtension",
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "$(PRODUCT_NAME)",
        "CFBundleShortVersionString": Plist.Value(stringLiteral: version),
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.share-services",
          "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).ShareViewController",
          "NSExtensionAttributes": [
            "NSExtensionActivationRule": """
            SUBQUERY (
                extensionItems,
                $extensionItem,
                SUBQUERY (
                    $extensionItem.attachments,
                    $attachment,
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.audio" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.mpeg-4-audio" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.mp3" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "com.microsoft.windows-media-wma" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.aifc-audio" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.aiff-audio" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.midi-audio" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.ac3-audio" ||
                    ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "com.microsoft.waveform-audio"
                ).@count == $extensionItem.attachments.@count
            ).@count == 1
            """,
          ],
        ],
      ]),
      sources: "App/ShareExtension/ShareViewController.swift",
      entitlements: "App/Support/ShareExtension.entitlements",
      dependencies: [
        .external(name: "AudioKit"),
      ]
    ),

    // MARK: - AppKit

    .target(
      name: "WhisperBoardKit",
      destinations: appDestinations,
      product: .framework,
      bundleId: "me.igortarasenko.WhisperboardKit",
      deploymentTargets: appDeploymentTargets,
      infoPlist: .extendingDefault(with: [:]),
      sources: "AppKit/Sources/**",
      resources: "AppKit/Resources/**",
      dependencies: [
        .sdk(name: "c++", type: .library, status: .required),

        .external(name: "AsyncAlgorithms"),
        .external(name: "AudioKit"),
        .external(name: "ComposableArchitecture"),
        .external(name: "DependenciesAdditions"),
        .external(name: "DSWaveformImage"),
        .external(name: "DSWaveformImageViews"),
        .external(name: "DynamicColor"),
        .external(name: "FluidGradient"),
        .external(name: "Inject"),
        .external(name: "KeychainAccess"),
        .external(name: "Logging"),
        .external(name: "Lottie"),
        .external(name: "NavigationTransitions"),
        .external(name: "Popovers"),
        .external(name: "PulseLogHandler"),
        .external(name: "PulseUI"),
        .external(name: "SwiftUIIntrospect"),
        .external(name: "VariableBlurView"),
        .external(name: "WhisperKit"),
        // .external(name: "RevenueCat"),

        .package(product: "whisper"),
      ] + (isAppStore ? [.package(product: "RollbarNotifier")] : []),
      settings: .settings(
        base: [
          "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/AppKit/Support/Bridging.h",
        ],
        debug: [
          "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "\(additionalCondition) DEBUG",
        ],
        release: [
          "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "\(additionalCondition)",
        ]
      )
    ),
    .target(
      name: "WhisperBoardKitTests",
      destinations: appDestinations,
      product: .unitTests,
      bundleId: "me.igortarasenko.WhisperboardKitTests",
      infoPlist: .default,
      sources: "AppKit/Tests/**",
      dependencies: [
        .target(name: "WhisperBoardKit"),
        .external(name: "SnapshotTesting"),
      ]
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
