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
  }

  let store: StoreOf<SettingsScreen>

  @ObservedObject var viewStore: ViewStore<ViewState, SettingsScreen.Action>
  @EnvironmentObject var tabBarViewModel: TabBarViewModel

  @ObserveInjection var inject

  var modelSelectorStore: StoreOf<ModelSelector> {
    store.scope(state: \.modelSelector, action: SettingsScreen.Action.modelSelector)
  }

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
        takenSpacePercentage: state.takenSpacePercentage
      )
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SettingsSheetButton(
            icon: Image(systemName: "square.and.arrow.down"),
            iconBGColor: .systemBlue.lighten(by: 0.1),
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

          SettingsInlinePickerButton(
            icon: Image(systemName: "globe"),
            iconBGColor: .systemGreen.darken(by: 0.1),
            title: "Language",
            choices: viewStore.availableLanguages.map(\.name.titleCased),
            selectedIndex: Binding(
              get: { viewStore.availableLanguages.firstIndex(of: viewStore.settings.voiceLanguage) ?? 0 },
              set: { viewStore.$settings.voiceLanguage.wrappedValue = viewStore.availableLanguages[$0] }
            )
          )

        } header: {
          Text("Local Transcription")
        }
        .listRowBackground(Color.DS.Background.secondary)
        .listRowSeparator(.hidden)

        #if DEBUG
        Section {
          RemoteTranscriptionImage()
          SettingsToggleButton(
            icon: Image(systemName: "mic"),
            iconBGColor: .systemOrange.darken(by: 0.1),
            title: "Fast Cloud Transcription",
            isOn: viewStore.$settings.isRemoteTranscriptionEnabled
          )
        } header: {
          Text("Pro Features")
        }
          .listRowBackground(Color.DS.Background.secondary)
          .listRowSeparator(.hidden)
        #endif

        Section {
          SettingsToggleButton(
            icon: Image(systemName: "wand.and.stars"),
            iconBGColor: .systemPink.darken(by: 0.05),
            title: "Enable Fixtures",
            isOn: viewStore.$settings.useMockedClients
          )
          SettingsSheetButton(
            icon: Image(systemName: "ladybug"),
            iconBGColor: .systemRed.darken(by: 0.05),
            title: "Show logs"
          ) {
            ScrollView {
              Text((try? String(contentsOfFile: Configs.logFileURL.path())) ?? "No logs...")
                .font(.footnote)
                .monospaced()
                .padding()
            }
          }
        } header: {
          Text("Debug")
        }
        .listRowBackground(Color.DS.Background.secondary)
        .listRowSeparator(.hidden)

        Section {
          Group {
            VStack(alignment: .leading, spacing: .grid(1)) {
              HStack(spacing: 0) {
                Text("Taken: \(viewStore.takenSpace)")
                  .font(.DS.bodyM)
                  .foregroundColor(.DS.Text.base)
                Spacer()
                Text("Available: \(viewStore.freeSpace)")
                  .font(.DS.bodyM)
                  .foregroundColor(.DS.Text.base)
              }

              GeometryReader { geometry in
                HStack(spacing: 0) {
                  LinearGradient.easedGradient(
                    colors: [
                      .systemPurple,
                      .systemOrange,
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                  )
                  .frame(width: geometry.size.width * viewStore.takenSpacePercentage)
                  Color.DS.Background.tertiary
                }
              }
              .frame(height: .grid(4))
              .continuousCornerRadius(.grid(1))
            }
            .padding(.horizontal, .grid(4))
            .padding(.vertical, .grid(2))
          }

          #if DEBUG
          SettingsToggleButton(
            icon: Image(systemName: "icloud.and.arrow.up"),
            iconBGColor: .systemBlue,
            title: "iCloud Sync",
            isOn: viewStore.$settings.isICloudSyncEnabled
          )
            .disabled(viewStore.isICloudSyncInProgress)
            .blur(radius: viewStore.isICloudSyncInProgress ? 3 : 0)
            .overlay(viewStore.isICloudSyncInProgress ? ProgressView().progressViewStyle(.circular) : nil)
          #endif

          SettingsButton(
            icon: Image(systemName: "trash"),
            iconBGColor: .systemYellow,
            title: "Delete Storage"
          ) {
            viewStore.send(.deleteStorageTapped)
          }
        } header: {
          Text("Storage")
        }
        .listRowBackground(Color.DS.Background.secondary)
        .listRowSeparator(.hidden)

        Section {
          SettingsButton(
            icon: Image(systemName: "star.fill"),
            iconBGColor: .systemYellow.darken(by: 0.05),
            title: "Rate the App"
          ) {
            viewStore.send(.rateAppTapped)
          }

          SettingsButton(
            icon: Image(systemName: "exclamationmark.triangle"),
            iconBGColor: .systemRed,
            title: "Report a Bug"
          ) {
            viewStore.send(.reportBugTapped)
          }

          SettingsButton(
            icon: Image(systemName: "sparkles"),
            iconBGColor: .systemPurple.darken(by: 0.1),
            title: "Suggest New Feature"
          ) {
            viewStore.send(.suggestFeatureTapped)
          }
        }
        .listRowBackground(Color.DS.Background.secondary)
        .listRowSeparator(.hidden)

        Section {
          footerView()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
      }
      .scrollContentBackground(.hidden)
      .removeNavigationBackground()
      .navigationBarTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .applyTabBarContentInset()
    }
    .alert(store: store.scope(state: \.$alert, action: { .alert($0) }))
    .task { viewStore.send(.task) }
    .enableInjection()
  }

  @ViewBuilder
  private func footerView() -> some View {
    VStack(spacing: .grid(1)) {
      Text("v\(viewStore.appVersion) (\(viewStore.buildNumber))")
        .font(.DS.bodyM)
        .foregroundColor(.DS.Text.subdued)
      Text("Made with ♥ in Amsterdam")
        .font(.DS.bodyM)
        .mask {
          LinearGradient.easedGradient(
            colors: [
              .systemPurple,
              .systemRed,
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
          )
        }
      Button { viewStore.send(.openPersonalWebsite) } label: {
        Text("by Igor Tarasenko")
          .font(.DS.bodyM)
          .foregroundColor(.DS.Text.accentAlt)
      }
    }
    .frame(maxWidth: .infinity)

    HStack(spacing: .grid(1)) {
      Button("Saik0s/Whisperboard") {
        viewStore.send(.openGitHub)
      }
    }
    .buttonStyle(SmallButtonStyle())
    .frame(maxWidth: .infinity)
    .onAppear {
      viewStore.send(.modelSelector(.reloadSelectedModel))
      viewStore.send(.updateInfo)
    }
  }
}

// MARK: - SmallButtonStyle

struct SmallButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.DS.bodyM)
      .foregroundColor(.DS.Text.accentAlt)
      .padding(.horizontal, .grid(2))
      .padding(.vertical, .grid(1))
      .background(
        RoundedRectangle(cornerRadius: .grid(1))
          .fill(Color.DS.Background.accentAlt.opacity(0.2))
      )
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
  }
}

private extension String {
  static let modelSelectorFooter = """
  Whisper ASR, by OpenAI, is an advanced system that converts spoken words into written text. It's perfect for transcribing conversations or speeches.

  The model is a neural network that takes an audio file as input and outputs a sequence of characters.
  """
}

// MARK: - SettingsScreen_Previews

struct SettingsScreen_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      SettingsScreenView(
        store: Store(
          initialState: SettingsScreen.State(),
          reducer: { SettingsScreen() }
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}
