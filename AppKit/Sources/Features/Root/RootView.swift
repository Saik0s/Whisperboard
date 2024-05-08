import Combine
import ComposableArchitecture
import Inject
import NavigationTransitions
import SwiftUI

// MARK: - RootView

struct RootView: View {
  @Perception.Bindable var store: StoreOf<Root>
  @Perception.Bindable private var tabBarViewModel: TabBarViewModel
  @Perception.Bindable private var recordButtonModel: RecordButtonModel

  @Namespace private var namespace

  init(store: StoreOf<Root>) {
    self.store = store
    tabBarViewModel = TabBarViewModel()
    recordButtonModel = RecordButtonModel(isExpanded: true)
  }

  var body: some View {
    WithPerceptionTracking {
      TabBarContainerView(
        selectedIndex: $store.selectedTab,
        screen1: NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
          RecordingListScreenView(store: store.scope(state: \.recordingListScreen, action: \.recordingListScreen))
        } destination: { store in
          switch store.case {
          case let .details(store):
            RecordingDetailsView(store: store)
          }
        }
          .navigationTransition(.slide),
        screen2: RecordScreenView(store: store.scope(state: \.recordScreen, action: \.recordScreen)),
        screen3: NavigationStack {
          SettingsScreenView(store: store.scope(state: \.settingsScreen, action: \.settingsScreen))
        }
      )
      .accentColor(.white)
      .task { await store.send(.task).finish() }
      .environment(tabBarViewModel)
      .environment(recordButtonModel)
      .environment(NamespaceContainer(namespace: namespace))
      .animation(.easeInOut(duration: 0.2), value: tabBarViewModel.isVisible)
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          tabBarViewModel.isVisible = true
        }
      }
      .onChange(of: store.path.isEmpty) { isEmpty in
        // Don't show tab bar if not on the root screen
        tabBarViewModel.isVisible = isEmpty
      }
    }
  }
}

// MARK: - NamespaceContainer

@Perceptible
class NamespaceContainer {
  var namespace: Namespace.ID

  init(namespace: Namespace.ID) {
    self.namespace = namespace
  }
}
