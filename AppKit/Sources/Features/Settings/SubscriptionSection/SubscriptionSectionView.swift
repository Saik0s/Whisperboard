import ComposableArchitecture
import Inject
import Lottie
import SwiftUI
import VariableBlurView

// MARK: - SubscriptionSection

struct SubscriptionSection: ReducerProtocol {
  struct State: Equatable {
    @PresentationState var details: SubscriptionDetails.State?
  }

  enum Action: Equatable {
    case details(PresentationAction<SubscriptionDetails.Action>)
    case sectionTapped
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce<State, Action> { state, action in
      switch action {
      case .details:
        return .none

      case .sectionTapped:
        guard state.details == nil else { return .none }
        state.details = .init()
        return .none
      }
    }
    .ifLet(\.$details, action: /Action.details) {
      SubscriptionDetails()
    }
  }
}

// MARK: - SubscriptionSectionView

struct SubscriptionSectionView: View {
  @ObserveInjection var inject

  let store: StoreOf<SubscriptionSection>

  @State var sectionSize: CGSize = .zero
  @State var playbackMode = LottiePlaybackMode.paused(at: .progress(0))

  init(store: StoreOf<SubscriptionSection>) {
    self.store = store
  }

  var body: some View {
    Button {
      store.send(.sectionTapped)
    } label: {
      VStack(alignment: .leading, spacing: .grid(2)) {
        LottieView(animation: AnimationAsset.wiredGradient407CrownKingLord.animation)
          .resizable()
          .playbackMode(playbackMode)
          .animationDidFinish { _ in
            playbackMode = .paused(at: .progress(0))
          }
          .frame(width: 30, height: 30)
          .padding(.grid(1))
          .background {
            Circle().fill(Color.DS.neutral07100)
          }

        VStack(alignment: .leading, spacing: .grid(1)) {
          HStack(spacing: .grid(1)) {
            Text("WhisperBoard")
              .font(.DS.titleSmall)

            Text("PRO")
              .font(.DS.badge)
              .padding(.horizontal, 3)
              .padding(.vertical, 1)
              .background {
                RoundedRectangle(cornerRadius: .grid(1))
                  .fill(Color.DS.Text.accent)
              }
          }
          .accessibilityElement(children: .combine)

          Text("Get 3 days free.\nContribute to ongoing development.")
            .textStyle(.captionBase)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: .grid(2)) {
          Text("Try Now")
            .font(.DS.body)
            .padding(.bottom, .grid(1))
            .background(alignment: .bottom) {
              Rectangle().fill(Color.DS.Text.base).frame(height: 1)
            }

          LottieView(animation: AnimationAsset.wiredOutline225Arrow14.animation)
            .resizable()
            .playbackMode(playbackMode)
            .frame(width: 30, height: 30)
        }
        .padding(.vertical, .grid(1))
      }
      .foregroundColor(.DS.Text.base)
      .background {
        Color.DS.Background.tertiary.darken(by: 0.1)
          .blur(radius: 10)
          .opacity(0.8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .multilineTextAlignment(.leading)
      .padding(.grid(4))
      .background(sectionBackground())
      .readSize { sectionSize = $0 }
      .continuousCornerRadius(.grid(4))
    }
    .trySubscriptionButtonStyle(playbackMode: $playbackMode)
    .sheet(store: store.scope(state: \.$details, action: SubscriptionSection.Action.details)) { store in
      SubscriptionDetailsView(store: store)
    }
    .onAppear {
      playbackMode = .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
    }
    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .enableInjection()
  }

  private func sectionBackground() -> some View {
    ZStack {
      LinearGradient(
        colors: [
          .DS.Background.tertiary.darken(by: 0.1),
          .DS.Background.secondary.darken(by: 0.1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .addBorder(
        LinearGradient(
          colors: [
            .DS.Background.tertiary.lighten().opacity(0.05),
            .DS.Background.tertiary.lighten().opacity(0.2),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        width: 1,
        cornerRadius: .grid(3)
      )

      WhisperBoardKitAsset.subscriptionHeader.swiftUIImage
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity)
        .offset(x: sectionSize.width / 4)

      Color.DS.Background.secondary
        .opacity(0.3)
    }
    .clipped()
  }
}

// MARK: - TrySubscriptionButtonStyle

struct TrySubscriptionButtonStyle: ButtonStyle {
  @Binding var playbackMode: LottiePlaybackMode
  @State var feedbackGenerator = UISelectionFeedbackGenerator()

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .overlay {
        RoundedRectangle(cornerRadius: .grid(4))
          .fill(Color.DS.Text.base)
          .shining(
            animation: .easeInOut(duration: 0.7).delay(7).repeatForever(autoreverses: false),
            gradient: Gradient(colors: [.clear, .black.opacity(0.1), .black.opacity(0.1), .clear])
          )
      }
      .shiningCard(defaultDegrees: 3, triggerDegrees: -8, isTapped: .constant(configuration.isPressed))
      .shadow(color: Color.DS.Shadow.accent.opacity(0.4), radius: 35, x: 0, y: 20)
      .onChange(of: configuration.isPressed) { isPressed in
        if isPressed {
          playbackMode = .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
        }
        feedbackGenerator.selectionChanged()
      }
      .animation(.gentleBounce(), value: configuration.isPressed)
  }
}

extension View {
  func trySubscriptionButtonStyle(playbackMode: Binding<LottiePlaybackMode>) -> some View {
    buttonStyle(TrySubscriptionButtonStyle(playbackMode: playbackMode))
  }
}

#if DEBUG
  struct SubscriptionSectionView_Previews: PreviewProvider {
    static var previews: some View {
      VStack {
        SubscriptionSectionView(
          store: Store(
            initialState: SubscriptionSection.State(),
            reducer: { SubscriptionSection() }
          )
        )
      }
      .previewBasePreset()
    }
  }
#endif
