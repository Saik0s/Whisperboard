import Combine
import Common
import ComposableArchitecture
import FluidGradient
import Inject
import NavigationTransitions
import SwiftUI

// MARK: - RootView

@MainActor
struct RootView: View {
  @Perception.Bindable var store: StoreOf<Root>
  @State var isGoToNewRecordingPopupPresented = false

  @Namespace private var namespace

  var body: some View {
    WithPerceptionTracking {
      NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        RecordScreenView(store: store.scope(state: \.recordScreen, action: \.recordScreen))
          .background {
            FluidGradient(
              blobs: [Color(hexString: "#000040"), Color(hexString: "#000030"), Color(hexString: "#000020")],
              highlights: [Color(hexString: "#1D004D"), Color(hexString: "#300055"), Color(hexString: "#100020")],
              speed: 0.2,
              blur: 0.75
            )
            .ignoresSafeArea()
          }
          .background(Color.DS.Background.primary)
          .toolbar {
            ToolbarItem(placement: .bottomBar) {
              bottomBar
            }
          }
      } destination: { store in
        switch store.case {
        case .list:
          RecordingListScreenView(store: self.store.scope(state: \.recordingListScreen, action: \.recordingListScreen))
        case .settings:
          SettingsScreenView(store: self.store.scope(state: \.settingsScreen, action: \.settingsScreen))
        case let .details(store):
          RecordingDetailsView(store: store)
        }
      }
//      .navigationTransition(.slide.combined(with: .fade(.in)), interactivity: .pan)

      .accentColor(.white)

      .task {
        store.send(.task)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          store.send(.recordingListScreen(.task))
          store.send(.settingsScreen(.task))
          store.send(.recordScreen(.micSelector(.task)))
          store.send(.settingsScreen(.premiumFeaturesSection(.onTask)))
        }
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

  var bottomBar: some View {
    HStack {
      Button(action: { store.send(.recordingListButtonTapped) }) {
        Image(systemName: "list.bullet")
          .foregroundColor(.DS.Text.base)
      }

      Spacer()

      Button(action: { store.send(.settingsButtonTapped) }) {
        Image(systemName: "gear")
          .foregroundColor(.DS.Text.base)
      }
    }
  }
}
