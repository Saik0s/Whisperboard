import Combine
import Common
import ComposableArchitecture
import Inject
import NavigationTransitions
import SwiftUI

// MARK: - RootView

@MainActor
struct RootView: View {
  @Perception.Bindable var store: StoreOf<Root>
  @Perception.Bindable private var tabBarViewModel: TabBarViewModel
  @Perception.Bindable private var recordButtonModel: RecordButtonModel
  @State var isGoToNewRecordingPopupPresented = false

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
      .task {
        store.send(.task)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          store.send(.recordingListScreen(.task))
          store.send(.settingsScreen(.task))
          store.send(.recordScreen(.micSelector(.task)))
        }
      }
      .environment(tabBarViewModel)
      .environment(recordButtonModel)
      .environment(NamespaceContainer(namespace: namespace))
      .animation(.easeInOut(duration: 0.1), value: tabBarViewModel.isVisible)
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          tabBarViewModel.isVisible = true
        }
      }
      .onChange(of: store.path.isEmpty) { isEmpty in
        // Don't show tab bar if not on the root screen
        tabBarViewModel.isVisible = isEmpty
      }
      .popover(
        present: $isGoToNewRecordingPopupPresented,
        attributes: {
          $0.position = .absolute(originAnchor: .top, popoverAnchor: .bottom)
          $0.presentation = .init(animation: .hardShowHide(), transition: .move(edge: .bottom).combined(with: .opacity))
          $0.dismissal = .init(
            animation: .hardShowHide(),
            transition: .move(edge: .bottom).combined(with: .opacity),
            mode: [.dragDown, .tapOutside]
          )
        }
      ) {
        VStack(spacing: .grid(4)) {
          Text("View the new recording?")
            .textStyle(.label)
            .foregroundColor(.DS.Text.base)

          Button("View Recording") {
            store.send(.goToNewRecordingButtonTapped)
          }.secondaryButtonStyle()
        }
        .padding(.grid(3))
        .cardStyle()
      }
      .bind($store.isGoToNewRecordingPopupPresented, to: $isGoToNewRecordingPopupPresented)
      .onChange(of: isGoToNewRecordingPopupPresented) { isPresented in
        if isPresented {
          withAnimation(.spring.delay(5)) {
            isGoToNewRecordingPopupPresented = false
          }
        }
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
