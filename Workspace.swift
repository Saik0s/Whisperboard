import ProjectDescription

let workspace = Workspace(
  name: "WhisperBoard",
  projects: ["App", "AppKit"],
  generationOptions: .options(
    enableAutomaticXcodeSchemes: false,
    lastXcodeUpgradeCheck: Version(15, 0, 0),
    renderMarkdownReadme: true
  )
)
