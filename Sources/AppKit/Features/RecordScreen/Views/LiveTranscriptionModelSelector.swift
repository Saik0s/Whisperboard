import Common
import ComposableArchitecture
import Inject
import Popovers
import Pow
import SwiftUI

// MARK: - LiveTranscriptionModelSelector

@Reducer
struct LiveTranscriptionModelSelector {
  @ObservableState
  struct State: Equatable {
    @Shared(.availableModels) var availableModels: [Model]
    @Shared(.premiumFeatures) var premiumFeatures: PremiumFeaturesStatus
    @Shared(.settings) var settings

    @Presents var purchaseLiveTranscriptionModal: PurchaseLiveTranscriptionModal.State?

    var showInfoPopup: Bool = false
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case purchaseLiveTranscriptionModal(PresentationAction<PurchaseLiveTranscriptionModal.Action>)
    case upgradeButtonTapped
  }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .purchaseLiveTranscriptionModal(.presented(.delegate(.didFinishTransaction))):
        state.purchaseLiveTranscriptionModal = nil
        return .none

      case .purchaseLiveTranscriptionModal:
        return .none

      case .upgradeButtonTapped:
        state.purchaseLiveTranscriptionModal = PurchaseLiveTranscriptionModal.State()
        return .none
      }
    }
    .ifLet(\.$purchaseLiveTranscriptionModal, action: \.purchaseLiveTranscriptionModal) {
      PurchaseLiveTranscriptionModal()
    }
  }
}

// MARK: - LiveTranscriptionModelSelectorView

struct LiveTranscriptionModelSelectorView: View {
  @Perception.Bindable var store: StoreOf<LiveTranscriptionModelSelector>

  @ObserveInjection private var injection

  var body: some View {
    WithPerceptionTracking {
      ZStack {
        if store.state.premiumFeatures.liveTranscriptionIsPurchased == nil {
          ProgressView()
        } else if store.state.premiumFeatures.liveTranscriptionIsPurchased == false {
          LockedFeatureView(
            title: "Live Transcription",
            description: "Hey there! Wanna try Live Transcription? It's a cool feature you can unlock by upgrading.",
            onInfoTap: { store.send(.set(\.showInfoPopup, !store.state.showInfoPopup)) },
            onUpgradeTap: { store.send(.upgradeButtonTapped) }
          )
        } else {
          LabeledContent("Live Transcription", content: {
            Picker("Model", selection: $store.settings.selectedModelName) {
              ForEach(store.state.availableModels) { model in
                Text(model.name).tag(model.id)
              }
            }
            .pickerStyle(MenuPickerStyle())

            Button(action: { store.send(.set(\.showInfoPopup, true)) }) {
              Image(systemName: "info.circle")
                .foregroundColor(.blue)
            }
            .padding(.leading, .grid(2))
          })
        }
      }
      .popover(
        present: $store.state.showInfoPopup,
        attributes: {
          $0.presentation = .init(animation: .bouncy, transition: .movingParts.swoosh.combined(with: .opacity))
          $0.dismissal = .init(
            animation: .bouncy,
            transition: .movingParts.swoosh.combined(with: .opacity),
            mode: [.dragDown, .dragUp]
          )
          $0.blocksBackgroundTouches = true
        }
      ) {
        InfoPopupView()
      } background: {
        Rectangle().fill(.ultraThinMaterial)
      }
      .sheet(item: $store.scope(state: \.purchaseLiveTranscriptionModal, action: \.purchaseLiveTranscriptionModal)) { store in
        PurchaseLiveTranscriptionModalView(store: store)
      }
      .enableInjection()
    }
  }
}

// MARK: - LockedFeatureView

struct LockedFeatureView: View {
  let title: String
  let description: String
  let onInfoTap: () -> Void
  let onUpgradeTap: () -> Void

  @State private var isPressed: Bool = false
  @State private var shine: Bool = false

  var body: some View {
    HStack {
      Image(systemName: "lock.fill")
        .font(.title)
        .foregroundColor(Color(.systemYellow))
        .shadow(color: Color(.systemYellow).opacity(0.5), radius: 8, x: 0, y: 0)

      Text(description)
        .textStyle(.subheadline)
        .foregroundColor(.DS.Text.base)
        .padding(.leading, .grid(1))
        .padding(.trailing, .grid(7))
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
    ._onButtonGesture {
      isPressed = $0
    } perform: {
      onUpgradeTap()
    }
    .overlay(alignment: .topTrailing) {
      Button(action: onInfoTap) {
        Image(systemName: "info.circle")
          .foregroundColor(.DS.Text.base)
          .font(.body)
          .padding(8)
      }
    }
    .conditionalEffect(.pushDown, condition: isPressed)
    .compositingGroup()
    .changeEffect(.shine.delay(1), value: shine, isEnabled: !shine)
    .onAppear { _ = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in withAnimation { shine.toggle() } } }
  }
}

// MARK: - InfoPopupView

struct InfoPopupView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Live Transcription")
        .font(.title)
        .fontWeight(.bold)

      Text(
        "Live Transcription converts speech to text in real-time as you speak. It uses advanced AI models to process audio and generate accurate transcripts instantly."
      )
      .font(.body)

      Text("How to use:")
        .font(.headline)
        .padding(.top, 8)

      VStack(alignment: .leading, spacing: 8) {
        Text("1. Select a transcription model")
        Text("2. Start recording your audio")
        Text("3. Watch as text appears in real-time")
        Text("4. Edit or export your transcript when finished")
      }
      .font(.body)

      Text("Benefits:")
        .font(.headline)
        .padding(.top, 8)

      VStack(alignment: .leading, spacing: 8) {
        Text("• Instant feedback on your speech")
        Text("• Easily capture and review spoken content")
        Text("• Save time on manual transcription")
        Text("• Support for multiple languages")
      }
      .font(.body)
    }
    .padding(.grid(4))
    .cardStyle()
  }
}
