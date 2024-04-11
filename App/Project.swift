import Foundation
import ProjectDescription
import ProjectDescriptionHelpers

let projectSettings: SettingsDictionary = [
  "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
  "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
  "CODE_SIGN_STYLE": "Automatic",
  "IPHONEOS_DEPLOYMENT_TARGET": SettingValue(stringLiteral: deploymentTargetString),
  "MARKETING_VERSION": SettingValue(stringLiteral: version),
  "ENABLE_BITCODE": "NO",
  "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
]

let debugSettings: SettingsDictionary = [
  "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -enable-actor-data-race-checks",
  "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
]

let releaseSettings: SettingsDictionary = [
  :
]

func appTarget() -> Target {
  Target.target(
    name: "WhisperBoard",
    destinations: appDestinations,
    product: .app,
    bundleId: "me.igortarasenko.Whisperboard",
    deploymentTargets: appDeploymentTargets,
    infoPlist: .extendingDefault(with: [
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
        "UISceneConfigurations": [
        ],
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
    ]),
    sources: .paths([.relativeToManifest("Sources/**")]),
    resources: ["Resources/Assets.xcassets"],
    entitlements: "Support/app.entitlements",
    scripts: [
      .post(
        path: "../ci_scripts/post_build_checks.sh",
        name: "Additional Checks",
        basedOnDependencyAnalysis: false
      ),
    ],
    dependencies: [
      .target(name: "ShareExtension"),
      .project(target: "WhisperBoardKit", path: "../AppKit"),
    ]
  )
}

func shareExtensionTarget() -> Target {
  Target.target(
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
    sources: .paths([.relativeToManifest("ShareExtension/ShareViewController.swift")]),
    entitlements: "Support/ShareExtension.entitlements",
    dependencies: [
      .external(name: "AudioKit"),
    ]
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
  settings: .settings(
    base: projectSettings,
    debug: debugSettings,
    release: releaseSettings,
    defaultSettings: .recommended
  ),
  targets: [
    appTarget(),
    shareExtensionTarget(),
    // ],
    // schemes: [
    //   Scheme(
    //     name: "WhisperBoard",
    //     shared: true,
    //     buildAction: .buildAction(targets: ["WhisperBoard"]),
    //     runAction: .runAction(
    //       executable: "WhisperBoard",
    //       options: .options(
    //         storeKitConfigurationPath: "Support/Whisperboard.storekit",
    //         enableGPUFrameCaptureMode: .metal
    //       ),
    //       diagnosticsOptions: .options(mainThreadCheckerEnabled: true)
    //     )
    //   ),
    // ],
    // additionalFiles: [
    //   "Support/Whisperboard.storekit",
  ]
)
