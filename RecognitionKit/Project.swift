import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.frameworkProject(
  name: "RecognitionKit",
  mainDependencies: [
    .external(name: "whisper"),
  ],
  testDependencies: [
  ],
  additionalProjectSettings: [
    "OTHER_LDFLAGS": "-lc++ $(inherited)",
  ],
  additionalDebugSettings: [
    "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Sources/Common/Bridging.h",
  ],
  additionalReleaseSettings: [
    "SWIFT_OBJC_BRIDGING_HEADER": "$SRCROOT/Sources/Common/Bridging.h",
  ],
  additionalTestResources: [
    .glob(pattern: "TestResources/**"),
    "../AppKit/Resources/ggml-tiny.bin",
  ]
)
