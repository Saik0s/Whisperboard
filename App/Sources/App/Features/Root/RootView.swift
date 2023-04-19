import AppDevUtils
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - Root

struct Root: ReducerProtocol {
  struct State: Equatable {
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settings = SettingsScreen.State()
    var selectedTab = 0
  }

  enum Action: Equatable {
    case task
    case recordingListScreen(RecordingListScreen.Action)
    case recordScreen(RecordScreen.Action)
    case settings(SettingsScreen.Action)
    case selectTab(Int)
  }

  @Dependency(\.transcriber) var transcriber: TranscriberClient

  var body: some ReducerProtocol<State, Action> {
    CombineReducers {
      Scope(state: \.recordingListScreen, action: /Action.recordingListScreen) {
        RecordingListScreen()
      }

      Scope(state: \.recordScreen, action: /Action.recordScreen) {
        RecordScreen()
      }

      Scope(state: \.settings, action: /Action.settings) {
        SettingsScreen()
      }

      Reduce<State, Action> { state, action in
        switch action {
        case let .recordScreen(.newRecordingCreated(recordingInfo)):
          state.recordingListScreen.selection = nil
          return .run { send in
            await send(.selectTab(0))
            await send(.recordingListScreen(.recordingSelected(id: recordingInfo.id)))
          }

        default:
          return .none
        }
      }

      Reduce { state, action in
        switch action {
        case .task:
          return .fireAndForget { @MainActor in
            for await state in transcriber.transcriberStateStream() {
              switch state {
              case .transcribing, .loadingModel, .modelLoaded:
                UIApplication.shared.isIdleTimerDisabled = true

              default:
                UIApplication.shared.isIdleTimerDisabled = false
              }
            }
          }

        case let .selectTab(tab):
          state.selectedTab = tab
          return .none

        default:
          return .none
        }
      }
    }
  }
}

// MARK: - RootView

struct RootView: View {
  @ObserveInjection var inject

  let store: StoreOf<Root>
  @ObservedObject var viewStore: ViewStoreOf<Root>

  init(store: StoreOf<Root>) {
    self.store = store
    viewStore = ViewStore(store) { $0 }
  }

  private var selectedTab: Int {
    viewStore.selectedTab
  }

  var body: some View {
    TabView {
      ZStack {
        RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: Root.Action.recordingListScreen))
          .opacity(selectedTab == 0 ? 1 : 0)

        RecordScreenView(store: store.scope(state: \.recordScreen, action: Root.Action.recordScreen))
          .opacity(selectedTab == 1 ? 1 : 0)

        SettingsScreenView(store: store.scope(state: \.settings, action: Root.Action.settings))
          .opacity(selectedTab == 2 ? 1 : 0)
      }
      .toolbarBackground(.hidden, for: .tabBar)
      .toolbar(selectedTab == 1 ? .hidden : .visible, for: .tabBar)
    }
    .accentColor(Color.DS.Text.base)
    .safeAreaInset(edge: .bottom) {
      HStack {
        if selectedTab != 1 { Spacer() }

        TabBarItem(icon: "list.bullet", tag: 0, selectedTab: viewStore.binding(get: \.selectedTab, send: Root.Action.selectTab))

        Spacer()

        TabBarItem(icon: "mic", tag: 1, selectedTab: viewStore.binding(get: \.selectedTab, send: Root.Action.selectTab))
          .offset(y: selectedTab == 1 ? -20 : 0)
          .opacity(selectedTab == 1 ? 0 : 1)

        Spacer()

        TabBarItem(icon: "gear", tag: 2, selectedTab: viewStore.binding(get: \.selectedTab, send: Root.Action.selectTab))

        if selectedTab != 1 { Spacer() }
      }
      .background(.ultraThinMaterial.opacity(selectedTab == 1 ? 0 : 1))
      .cornerRadius(25.0)
      .padding(.horizontal, selectedTab == 1 ? 16 : 64)
      .frame(height: 50.0)
    }
    .animation(.gentleBounce(), value: selectedTab)
    .task { viewStore.send(.task) }
    .enableInjection()
  }
}

// MARK: - TabBarItem

struct TabBarItem: View {
  let icon: String
  let tag: Int
  @Binding var selectedTab: Int

  var body: some View {
    Button(action: {
      withAnimation(.gentleBounce()) {
        selectedTab = tag
      }
    }) {
      Image(systemName: icon)
        .font(selectedTab == tag ? .DS.headlineM.weight(.bold) : .DS.headlineM.weight(.light))
        .frame(width: 50, height: 50)
        .foregroundColor(selectedTab == tag ? Color.DS.Text.accent : Color.DS.Text.base)
        .cornerRadius(10)
    }
  }
}

// MARK: - Root_Previews

struct Root_Previews: PreviewProvider {
  struct ContentView: View {
    var body: some View {
      RootView(
        store: Store(
          initialState: Root.State(),
          reducer: Root()
        )
      )
    }
  }

  static var previews: some View {
    ContentView()
  }
}
