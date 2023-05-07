import Foundation
import ProjectDescription

let version = "1.9.5"

let projectSettings: SettingsDictionary = [
  "GCC_TREAT_WARNINGS_AS_ERRORS": "YES",
  "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
  "CODE_SIGN_STYLE": "Automatic",
  "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
  "MARKETING_VERSION": SettingValue(stringLiteral: version),
  "OTHER_LDFLAGS": "-lc++ $(inherited)",
]

let debugSettings: SettingsDictionary = [
  "OTHER_SWIFT_FLAGS": "-D DEBUG $(inherited) -Xfrontend -warn-long-function-bodies=500 -Xfrontend -warn-long-expression-type-checking=500 -Xfrontend -debug-time-function-bodies -Xfrontend -enable-actor-data-race-checks",
  "OTHER_LDFLAGS": "-Xlinker -interposable $(inherited)",
]

let releaseSettings: SettingsDictionary = [
  :
]

func appTarget() -> Target {
  Target(
    name: "WhisperBoard",
    platform: .iOS,
    product: .app,
    bundleId: "me.igortarasenko.Whisperboard",
    deploymentTarget: .iOS(targetVersion: "16.0", devices: [.iphone, .ipad]),
    infoPlist: .extendingDefault(with: [
      "CFBundleShortVersionString": InfoPlist.Value.string(version),
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
    ]),
    sources: .paths([.relativeToManifest("Sources/**")]),
    resources: ["Resources/Assets.xcassets"],
    entitlements: .relativeToManifest("Resources/app.entitlements"),
    dependencies: [
      .target(name: "ShareExtension"),

      .project(target: "WhisperBoardKit", path: "../AppKit"),
    ]
  )
}

func shareExtensionTarget() -> Target {
  Target(
    name: "ShareExtension",
    platform: .iOS,
    product: .appExtension,
    bundleId: "me.igortarasenko.Whisperboard.ShareExtension",
    infoPlist: .extendingDefault(with: [
      "CFBundleDisplayName": "$(PRODUCT_NAME)",
      "CFBundleShortVersionString": InfoPlist.Value.string(version),
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
    entitlements: .relativeToManifest("ShareExtension/ShareExtension.entitlements"),
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
  ]
)
