import Common
import ComposableArchitecture
import Inject
import PulseUI
import SwiftUI

// MARK: - SettingsScreenView

struct SettingsScreenView: View {
  @Perception.Bindable var store: StoreOf<SettingsScreen>

  @Environment(TabBarViewModel.self) var tabBarViewModel: TabBarViewModel

  @ObserveInjection var inject

  var body: some View {
    WithPerceptionTracking {
      List {
        #if APPSTORE && DEBUG
          if !store.isSubscribed {
            SubscriptionSectionView(store: store.scope(state: \.subscriptionSection, action: \.subscriptionSection))
              .introspect(.listCell, on: .iOS(.v16, .v17)) {
                $0.clipsToBounds = false
              }
          }
        #endif

        ModelSectionView(store: store)
        SpeechSectionView(store: store)

        #if DEBUG
          DebugSectionView(store: store)
        #endif

        StorageSectionView(store: store)
        FeedbackSectionView(store: store)
        FooterSectionView(store: store)
      }
      .scrollContentBackground(.hidden)
      .removeNavigationBackground()
      .navigationBarTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .alert($store.scope(state: \.alert, action: \.alert))
      .onAppear { store.send(.updateInfo) }
      .applyTabBarContentInset()
    }
    .enableInjection()
  }
}

// MARK: - ModelSectionView

struct ModelSectionView: View {
  @Perception.Bindable var store: StoreOf<SettingsScreen>

  var body: some View {
    WithPerceptionTracking {
      Section {
        #if APPSTORE && DEBUG
          SettingsToggleButton(
            icon: .system(name: "wand.and.stars", background: .DS.Background.accent),
            title: "Cloud Transcription",
            isOn: $store.settings.isRemoteTranscriptionEnabled
          )
        #endif

        SettingsSheetButton(
          icon: .system(name: "square.and.arrow.down", background: .systemBlue.lighten(by: 0.1)),
          title: "Model",
          trailingText: store.selectedModelReadableName
        ) {
          ModelSelectorView(store: store.scope(state: \.modelSelector, action: \.modelSelector))
        }
      } header: {
        Text("Transcription")
      } footer: {
        Text("Whisper Model").bold() + Text("""
         - OpenAI's Automatic Speech Recognition tool. The 'tiny' model is optimal for long transcriptions due to its speed. \
        The 'medium' model specializes in high-quality slow transcriptions. Larger models consume significant resources \
        and might not perform well on older iOS devices.
        """)
      }
      .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)

      Section {
        SettingsToggleButton(
          icon: .system(name: "mic.fill", background: .systemRed),
          title: "Auto-Transcribe Recordings",
          isOn: $store.settings.isAutoTranscriptionEnabled
        )
      } footer: {
        Text(
          "Enable this option to automatically transcribe audio recordings as soon as you stop recording. When disabled, you'll need to manually initiate the transcription process for each recording."
        )
      }
      .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)

      Section {
        SettingsToggleButton(
          icon: .system(name: "cpu", background: .systemGreen),
          title: "Use GPU (Experimental)",
          isOn: $store.settings.isUsingGPU
        )
      } footer: {
        Text(
          "Enable this option to use the GPU for transcription. This option is experimental and might not work on all devices."
        )
      }
      .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
    }
  }
}

// MARK: - SpeechSectionView

struct SpeechSectionView: View {
  @Perception.Bindable var store: StoreOf<SettingsScreen>

  var body: some View {
    WithPerceptionTracking {
      Section("Speech") {
        SettingsInlinePickerButton(
          icon: .system(name: "globe", background: .systemGreen.darken(by: 0.1)),
          title: "Language",
          choices: store.availableLanguages.map(\.titleCased),
          selectedIndex: $store.selectedLanguageIndex
        )
      }
      .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)

      Section {
        SettingsToggleButton(
          icon: .system(name: "waveform.path.ecg", background: .systemPurple),
          title: "Allow Background Audio",
          isOn: $store.settings.shouldMixWithOtherAudio
        )
      } footer: {
        Text(
          "Turn this on to allow background audio from other apps to continue playing while you record. This app will lower the volume of other audio sources (ducking) during recording. Turn off to ensure other apps are paused and only your recording is captured."
        )
      }
      .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
    }
  }
}

// MARK: - DebugSectionView

#if DEBUG
  struct DebugSectionView: View {
    @Perception.Bindable var store: StoreOf<SettingsScreen>

    @State private var logs: [(Int, String)] = []

    var body: some View {
      WithPerceptionTracking {
        Section {
          SettingsToggleButton(
            icon: .system(name: "wand.and.stars", background: .systemTeal),
            title: "Enable Fixtures",
            isOn: $store.settings.useMockedClients
          )

          SettingsSheetButton(icon: .system(name: "ladybug", background: .systemGreen), title: "Show logs") {
            NavigationStack {
              ConsoleView(store: .shared)
            }
          }
        } header: {
          Text("Debug")
        }
        .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
      }
    }
  }
#endif

// MARK: - StorageSectionView

struct StorageSectionView: View {
  @Perception.Bindable var store: StoreOf<SettingsScreen>

  var body: some View {
    WithPerceptionTracking {
      Section {
        Group {
          VStack(alignment: .leading, spacing: .grid(1)) {
            HStack(spacing: 0) {
              Text("Taken: \(store.takenSpace)").textStyle(.body)

              Spacer()

              Text("Available: \(store.freeSpace)").textStyle(.body)
            }

            GeometryReader { geometry in
              WithPerceptionTracking {
                HStack(spacing: 0) {
                  LinearGradient.easedGradient(colors: [.systemPurple, .systemOrange], startPoint: .bottomLeading, endPoint: .topTrailing)
                    .frame(width: geometry.size.width * store.takenSpacePercentage)

                  Color.DS.Background.tertiary
                }
              }
            }
            .frame(height: .grid(4)).continuousCornerRadius(.grid(1))
          }
        }

        SettingsToggleButton(
          icon: .system(name: "icloud.and.arrow.up", background: .systemBlue),
          title: "iCloud Backup",
          isOn: $store.settings.isICloudSyncEnabled
        )
        .disabled(store.isICloudSyncInProgress)
        .blur(radius: store.isICloudSyncInProgress ? 3 : 0)
        .overlay(store.isICloudSyncInProgress ? ProgressView().progressViewStyle(.circular) : nil)
        .animation(.easeInOut, value: store.isICloudSyncInProgress)

        SettingsButton(icon: .system(name: "trash", background: .systemYellow.darken(by: 0.1)), title: "Delete Storage") {
          store.send(.deleteStorageTapped)
        }
      } header: {
        Text("Storage")
      }
      .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
    }
  }
}

// MARK: - FeedbackSectionView

struct FeedbackSectionView: View {
  @Perception.Bindable var store: StoreOf<SettingsScreen>

  var body: some View {
    WithPerceptionTracking {
      Section {
        SettingsButton(icon: .system(name: "star.fill", background: .systemYellow.darken(by: 0.05)), title: "Rate the App") {
          store.send(.rateAppTapped)
        }

        SettingsButton(icon: .system(name: "exclamationmark.triangle", background: .systemRed), title: "Report a Bug") {
          store.send(.reportBugTapped)
        }

        SettingsButton(icon: .system(name: "sparkles", background: .systemPurple.darken(by: 0.1)), title: "Suggest New Feature") {
          store.send(.suggestFeatureTapped)
        }
      }
      .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
    }
  }
}

// MARK: - FooterSectionView

struct FooterSectionView: View {
  @Perception.Bindable var store: StoreOf<SettingsScreen>

  var body: some View {
    WithPerceptionTracking {
      Section {
        VStack(spacing: .grid(1)) {
          Text("v\(store.appVersion) (\(store.buildNumber))").textStyle(.caption)
          Text("Made with ♥ in Amsterdam").foregroundColor(.DS.Text.accentAlt).textStyle(.caption)
            .mask { LinearGradient.easedGradient(colors: [.systemPurple, .systemRed], startPoint: .bottomLeading, endPoint: .topTrailing) }
          Button {
            store.send(.openPersonalWebsite)
          } label: {
            Text("by Igor Tarasenko").foregroundColor(.DS.Text.accentAlt).textStyle(.caption)
          }
        }
        .frame(maxWidth: .infinity)

        HStack(spacing: .grid(1)) { Button("Saik0s/Whisperboard") { store.send(.openGitHub) } }.buttonStyle(SmallButtonStyle())
          .frame(maxWidth: .infinity)
      }
      .listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
  }
}

// MARK: - SmallButtonStyle

struct SmallButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .textStyle(.secondaryButton)
      .padding(.horizontal, .grid(2))
      .padding(.vertical, .grid(1))
      .background(RoundedRectangle(cornerRadius: .grid(1)).fill(Color.DS.Background.accentAlt.opacity(0.2)))
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
  }
}
