import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - SettingsScreenView

struct SettingsScreenView: View {
  struct ViewState: Equatable {
    @BindingViewState var settings: Settings
    @BindingViewState var isICloudSyncInProgress: Bool
    @BindingViewState var isDebugLogPresented: Bool
    @BindingViewState var isModelSelectorPresented: Bool

    var appVersion: String
    var availableLanguages: IdentifiedArrayOf<VoiceLanguage>
    var buildNumber: String
    var freeSpace: String
    var selectedModelReadableName: String
    var takenSpace: String
    var takenSpacePercentage: Double
    var isSubscribed: Bool
  }

  let store: StoreOf<SettingsScreen>

  @ObservedObject var viewStore: ViewStore<ViewState, SettingsScreen.Action>
  @EnvironmentObject var tabBarViewModel: TabBarViewModel

  @ObserveInjection var inject

  var modelSelectorStore: StoreOf<ModelSelector> { store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector) }

  init(store: StoreOf<SettingsScreen>) {
    self.store = store
    viewStore = ViewStore(store) { state in
      ViewState(
        settings: state.$settings,
        isICloudSyncInProgress: state.$isICloudSyncInProgress,
        isDebugLogPresented: state.$isDebugLogPresented,
        isModelSelectorPresented: state.$isModelSelectorPresented,
        appVersion: state.appVersion,
        availableLanguages: state.availableLanguages,
        buildNumber: state.buildNumber,
        freeSpace: state.freeSpace,
        selectedModelReadableName: state.modelSelector.selectedModel.readableName,
        takenSpace: state.takenSpace,
        takenSpacePercentage: state.takenSpacePercentage,
        isSubscribed: state.isSubscribed
      )
    }
  }

  var body: some View {
    NavigationStack {
      List {
        if !viewStore.isSubscribed {
          SubscriptionSectionView(store: store.scope(state: \.subscriptionSection, action: SettingsScreen.Action.subscriptionSection))
            .introspect(.listCell, on: .iOS(.v16, .v17)) {
              $0.clipsToBounds = false
            }
        }

        ModelSectionView(viewStore: viewStore, modelSelectorStore: modelSelectorStore)
        SpeechSectionView(viewStore: viewStore)

        #if DEBUG
          DebugSectionView(viewStore: viewStore)
        #endif

        StorageSectionView(viewStore: viewStore)
        FeedbackSectionView(viewStore: viewStore)
        FooterSectionView(viewStore: viewStore)
      }
      .scrollContentBackground(.hidden)
      .removeNavigationBackground()
      .navigationBarTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .applyTabBarContentInset()
    }
    .alert(store: store.scope(state: \.$alert, action: { .alert($0) }))
    .task { viewStore.send(.task) }
    .onAppear {
      viewStore.send(.modelSelector(.reloadSelectedModel))
      viewStore.send(.updateInfo)
    }
    .enableInjection()
  }
}

// MARK: - ModelSectionView

struct ModelSectionView: View {
  @ObservedObject var viewStore: ViewStore<SettingsScreenView.ViewState, SettingsScreen.Action>
  var modelSelectorStore: StoreOf<ModelSelector>

  var body: some View {
    Section {
      #if APPSTORE
        SettingsToggleButton(
          icon: .system(name: "wand.and.stars", background: .DS.Background.accent),
          title: "Cloud Transcription",
          isOn: viewStore.$settings.isRemoteTranscriptionEnabled
        )
      #endif
      SettingsSheetButton(
        icon: .system(name: "square.and.arrow.down", background: .systemBlue.lighten(by: 0.1)),
        title: "Model",
        trailingText: viewStore.selectedModelReadableName
      ) {
        Form {
          Section {
            ForEachStore(modelSelectorStore.scope(state: \.modelRows, action: ModelSelector.Action.modelRow)) { modelRowStore in
              ModelRowView(store: modelRowStore)
            }
            .listRowBackground(Color.DS.Background.secondary)
          }
        }
        .onAppear { viewStore.send(.modelSelector(.reloadSelectedModel)) }
        .alert(store: modelSelectorStore.scope(state: \.$alert, action: { .alert($0) }))
      }
      .onAppear { viewStore.send(.modelSelector(.reloadSelectedModel)) }
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
  }
}

// MARK: - SpeechSectionView

struct SpeechSectionView: View {
  @ObservedObject var viewStore: ViewStore<SettingsScreenView.ViewState, SettingsScreen.Action>

  var body: some View {
    Section("Speech") {
      SettingsInlinePickerButton(
        icon: .system(name: "globe", background: .systemGreen.darken(by: 0.1)),
        title: "Language",
        choices: viewStore.availableLanguages.map(\.name.titleCased),
        selectedIndex: Binding(
          get: { viewStore.availableLanguages.firstIndex(of: viewStore.settings.voiceLanguage) ?? 0 },
          set: { viewStore.$settings.voiceLanguage.wrappedValue = viewStore.availableLanguages[$0] }
        )
      )
    }
    .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
  }
}

// MARK: - DebugSectionView

struct DebugSectionView: View {
  @ObservedObject var viewStore: ViewStore<SettingsScreenView.ViewState, SettingsScreen.Action>

  var body: some View {
    Section {
      SettingsToggleButton(
        icon: .system(name: "wand.and.stars", background: .systemTeal),
        title: "Enable Fixtures",
        isOn: viewStore.$settings.useMockedClients
      )
      SettingsSheetButton(icon: .system(name: "ladybug", background: .systemGreen), title: "Show logs") {
        ScrollView { Text((try? String(contentsOfFile: Configs.logFileURL.path())) ?? "No logs...").font(.footnote).monospaced().padding() }
      }
    } header: {
      Text("Debug")
    }
    .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
  }
}

// MARK: - StorageSectionView

struct StorageSectionView: View {
  @ObservedObject var viewStore: ViewStore<SettingsScreenView.ViewState, SettingsScreen.Action>

  var body: some View {
    Section {
      Group {
        VStack(alignment: .leading, spacing: .grid(1)) {
          HStack(spacing: 0) {
            Text("Taken: \(viewStore.takenSpace)")
              .textStyle(.body)

            Spacer()
            Text("Available: \(viewStore.freeSpace)")
              .textStyle(.body)
          }

          GeometryReader { geometry in
            HStack(spacing: 0) {
              LinearGradient.easedGradient(colors: [.systemPurple, .systemOrange], startPoint: .bottomLeading, endPoint: .topTrailing)
                .frame(width: geometry.size.width * viewStore.takenSpacePercentage)
              Color.DS.Background.tertiary
            }
          }
          .frame(height: .grid(4)).continuousCornerRadius(.grid(1))
        }
      }

      SettingsToggleButton(
        icon: .system(name: "icloud.and.arrow.up", background: .systemBlue),
        title: "iCloud Backup",
        isOn: viewStore.$settings.isICloudSyncEnabled
      ).disabled(viewStore.isICloudSyncInProgress)
        .blur(radius: viewStore.isICloudSyncInProgress ? 3 : 0)
        .overlay(viewStore.isICloudSyncInProgress ? ProgressView().progressViewStyle(.circular) : nil)
        .animation(.easeInOut, value: viewStore.isICloudSyncInProgress)

      SettingsButton(icon: .system(name: "trash", background: .systemYellow.darken(by: 0.1)), title: "Delete Storage") {
        viewStore.send(.deleteStorageTapped)
      }
    } header: {
      Text("Storage")
    }
    .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
  }
}

// MARK: - FeedbackSectionView

struct FeedbackSectionView: View {
  @ObservedObject var viewStore: ViewStore<SettingsScreenView.ViewState, SettingsScreen.Action>

  var body: some View {
    Section {
      SettingsButton(icon: .system(name: "star.fill", background: .systemYellow.darken(by: 0.05)), title: "Rate the App") {
        viewStore.send(.rateAppTapped)
      }

      SettingsButton(icon: .system(name: "exclamationmark.triangle", background: .systemRed), title: "Report a Bug") {
        viewStore.send(.reportBugTapped)
      }

      SettingsButton(icon: .system(name: "sparkles", background: .systemPurple.darken(by: 0.1)), title: "Suggest New Feature") {
        viewStore.send(.suggestFeatureTapped)
      }
    }
    .listRowBackground(Color.DS.Background.secondary).listRowSeparator(.hidden)
  }
}

// MARK: - FooterSectionView

struct FooterSectionView: View {
  @ObservedObject var viewStore: ViewStore<SettingsScreenView.ViewState, SettingsScreen.Action>

  var body: some View {
    Section {
      VStack(spacing: .grid(1)) {
        Text("v\(viewStore.appVersion) (\(viewStore.buildNumber))").textStyle(.caption)
        Text("Made with ♥ in Amsterdam").foregroundColor(.DS.Text.accentAlt).textStyle(.caption)
          .mask { LinearGradient.easedGradient(colors: [.systemPurple, .systemRed], startPoint: .bottomLeading, endPoint: .topTrailing) }
        Button {
          viewStore.send(.openPersonalWebsite)
        } label: {
          Text("by Igor Tarasenko").foregroundColor(.DS.Text.accentAlt).textStyle(.caption)
        }
      }
      .frame(maxWidth: .infinity)

      HStack(spacing: .grid(1)) { Button("Saik0s/Whisperboard") { viewStore.send(.openGitHub) } }.buttonStyle(SmallButtonStyle())
        .frame(maxWidth: .infinity)
    }
    .listRowBackground(Color.clear).listRowSeparator(.hidden)
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

// MARK: - SettingsScreen_Previews

struct SettingsScreen_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View { SettingsScreenView(store: Store(initialState: SettingsScreen.State(), reducer: { SettingsScreen() })) }
  }

  static var previews: some View { ContentView() }
}
