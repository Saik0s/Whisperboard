import Common
import ComposableArchitecture
import Inject
import Lottie
import Popovers
import Pow
import SwiftUI

// MARK: - LiveTranscriptionModelSelector

@Reducer
struct LiveTranscriptionModelSelector {
  @ObservableState
  struct State: Equatable {
    @Shared(.availableModels) var availableModels: [ModelSelector.State.ModelInfo]
    @Shared(.premiumFeatures) var premiumFeatures: PremiumFeaturesStatus
    @Shared(.settings) var settings

    @Presents var purchaseLiveTranscriptionModal: PurchaseLiveTranscriptionModal.State?

    var showInfoPopup = false

    var currentModelInfo: ModelSelector.State.ModelInfo? {
      availableModels.first { $0.id == settings.selectedModelName }
    }
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
            description: "Live Transcription: Real-time speech-to-text. Unlock now. Transform recording.",
            onInfoTap: { store.send(.set(\.showInfoPopup, !store.state.showInfoPopup)) },
            onUpgradeTap: { store.send(.upgradeButtonTapped) }
          )
        } else {
          VStack {
            HStack {
              #if APPSTORE
                LottieView(animation: AnimationAsset.wiredOutline2474SparklesGlitter.animation)
                  .playing(loopMode: .autoReverse)
                  .animationSpeed(0.3)
                  .resizable()
                  .frame(width: 24, height: 24)
              #endif

              Text("Live Transcription")
                .textStyle(.body)

              Spacer()

              Button(action: { store.send(.set(\.showInfoPopup, true)) }) {
                Image(systemName: "info.circle")
                  .foregroundColor(.DS.Text.base)
                  .font(.body)
              }
            }

            VStack(alignment: .leading, spacing: .grid(2)) {
              Toggle(isOn: $store.settings.isLiveTranscriptionEnabled) {
                Label("Enable Live Transcription", systemImage: "text.viewfinder")
                  .textStyle(.label)
              }

              LabeledContent {
                Picker("", selection: $store.settings.selectedModelName) {
                  ForEach(store.state.availableModels) { model in
                    (Text(model.title).foregroundColor(.DS.Text.base) +
                      Text("\(!model.isMultilingual || model.isDistilled ? " English" : "") (\(model.size))").foregroundColor(.DS.Text.subdued))
                      .font(.DS.body)
                      .tag(model.id)
                  }
                }
                .foregroundColor(.DS.Text.subdued)
              } label: {
                Label("Selected model", systemImage: "brain")
                  .textStyle(.label)
              }
              .disabled(store.settings.isLiveTranscriptionEnabled == false)

//            Divider()
//
//            if let currentModelInfo = store.state.currentModelInfo {
//              LabeledContent {
//                Text(currentModelInfo.size)
//              } label: {
//                Label("Model Size", systemImage: "arrow.down.circle")
//                  .textStyle(.label)
//              }
//
//              LabeledContent {
//                Text(currentModelInfo.isDistilled ? "Yes" : "No")
//              } label: {
//                Label("Distilled", systemImage: "bolt")
//                  .textStyle(.label)
//              }
//
//              LabeledContent {
//                Text(currentModelInfo.isMultilingual ? "Yes" : "No")
//              } label: {
//                Label("Multilingual", systemImage: "globe")
//                  .textStyle(.label)
//              }
//
//              LabeledContent {
//                Text(currentModelInfo.isTurbo ? "Yes" : "No")
//              } label: {
//                Label("Turbo", systemImage: "speedometer")
//                  .textStyle(.label)
//              }
//            }
            }
            .labelStyle(.titleOnly)
            .padding(.grid(4))
            .cardStyle()
          }
          .padding(.horizontal, .grid(4))
        }
      }
      .popover(
        present: $store.state.showInfoPopup,
        attributes: {
          $0.position = .relative(
            popoverAnchors: [
              .center,
            ]
          )
          $0.presentation = .init(animation: .snappy, transition: .movingParts.blur.combined(with: .opacity))
          $0.dismissal = .init(
            animation: .snappy,
            transition: .movingParts.blur.combined(with: .opacity),
            mode: [.dragDown, .dragUp, .tapOutside]
          )
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

  @State private var isPressed = false
  @State private var shine = false

  var body: some View {
    VStack(alignment: .leading, spacing: .grid(1)) {
      HStack(spacing: .grid(1)) {
        #if APPSTORE
          LottieView(animation: AnimationAsset.wiredOutline2474SparklesGlitter.animation)
            .playing(loopMode: .autoReverse)
            .animationSpeed(0.3)
            .resizable()
            .frame(width: 24, height: 24)
        #endif

        Text(title)
          .textStyle(.headline)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Text(description)
        .textStyle(.body)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button("Enable Live Transcription") { onUpgradeTap() }
        .underlinedArrowButtonStyle()
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
          .padding(.grid(4))
      }
    }
    .conditionalEffect(.pushDown, condition: isPressed)
    .compositingGroup()
    .changeEffect(.shine.delay(1), value: shine, isEnabled: !shine)
    .onAppear { _ = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in withAnimation { shine.toggle() } } }
  }
}

// MARK: - UnderlinedArrowButtonStyle

struct UnderlinedArrowButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.label

      Image(systemName: "arrow.right")
    }
    .foregroundColor(.DS.code02)
    .textStyle(.label)
    .padding(.bottom, .grid(1))
    .background(alignment: .bottom) {
      Rectangle()
        .fill(Color.DS.code02)
        .frame(height: 1)
    }
    .opacity(configuration.isPressed ? 0.7 : 1.0)
  }
}

extension View {
  func underlinedArrowButtonStyle() -> some View {
    buttonStyle(UnderlinedArrowButtonStyle())
  }
}

// MARK: - InfoPopupView

struct InfoPopupView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Live Transcription")
        .font(.title)
        .fontWeight(.bold)

      Text("Real-time speech-to-text, locally on your device!")
        .font(.headline)
        .fontWeight(.bold)

      Text("Experience the power of on-device transcription with total privacy.")
        .font(.body)
        .fontWeight(.medium)

      Text("Key Features:")
        .font(.headline)
        .padding(.top, 8)

      VStack(alignment: .leading, spacing: 8) {
        Text("• Select from multiple transcription models")
        Text("• 100% local processing")
        Text("• No internet connection required")
        Text("• Performance varies based on device capabilities")
      }
      .font(.body)

      Text("How it works:")
        .font(.headline)
        .padding(.top, 8)

      VStack(alignment: .leading, spacing: 8) {
        Text("1. Choose your preferred model")
        Text("2. Tap record to start transcribing")
        Text("3. Speak clearly for best results")
        Text("4. Watch your words appear in real-time")
      }
      .font(.body)

      Text("Note:")
        .font(.headline)
        .padding(.top, 8)

      Text(
        "If the selected model isn't downloaded, it will automatically download when you start recording. This may take a moment depending on your connection speed."
      )
      .font(.body)
      .fontWeight(.medium)
    }
    .padding(.grid(4))
    .cardStyle()
  }
}
