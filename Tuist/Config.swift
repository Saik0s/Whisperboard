import ProjectDescription

let config = Config(
  cache: .cache(
    profiles: [.profile(name: "Simulator", configuration: "debug", device: "iPhone 15 Pro Max")],
    path: .relativeToRoot("TuistCache")
  )
)
