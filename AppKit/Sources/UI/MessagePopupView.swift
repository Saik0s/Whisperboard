import ComposableArchitecture
import Foundation
import Popovers
import SwiftUI

public extension View {
  func messagePopup<ButtonAction>(
    store: Store<PresentationState<AlertState<ButtonAction>>, PresentationAction<ButtonAction>>
  ) -> some View {
    messagePopup(store: store, state: { $0 }, action: { $0 })
  }

  func messagePopup<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (ButtonAction) -> Action
  ) -> some View {
    modifier(
      PresentationMessagePopupModifier(
        viewStore: ViewStore(store, observe: { $0 }, removeDuplicates: { $0._id == $1._id }),
        toDestinationState: toDestinationState,
        fromDestinationAction: fromDestinationAction
      )
    )
  }
}

public extension View {
  @ViewBuilder
  func messagePopup<Action>(
    _ store: Store<AlertState<Action>?, Action>,
    dismiss: Action
  ) -> some View {
    modifier(
      NewMessagePopupModifier(
        viewStore: ViewStore(store, observe: { $0 }, removeDuplicates: { $0?.id == $1?.id }),
        dismiss: dismiss
      )
    )
  }
}

// MARK: - NewMessagePopupModifier

private struct NewMessagePopupModifier<Action>: ViewModifier {
  @StateObject var viewStore: ViewStore<AlertState<Action>?, Action>
  let dismiss: Action

  func body(content: Content) -> some View {
    content.messagePopup(
      isPresented: viewStore.binding(send: dismiss).isPresent(),
      message: viewStore.state?.message ?? TextState(""),
      title: viewStore.state?.title ?? TextState(""),
      buttonActions: viewStore.state?.buttons.map { button in
        switch button.action.type {
        case let .send(action):
          return { if let action { viewStore.send(action) } }
        case let .animatedSend(action, animation):
          return {
            if let action {
              _ = withAnimation(animation) {
                viewStore.send(action)
              }
            }
          }
        }
      } ?? [],
      buttonTitles: viewStore.state?.buttons.map(\.label) ?? []
    )
  }
}

extension View {
  func messagePopup(
    isPresented: Binding<Bool>,
    message: TextState,
    title: TextState,
    buttonActions: [() -> Void],
    buttonTitles: [TextState]
  ) -> some View {
    modifier(
      MessagePopupView(
        isPresented: isPresented,
        message: message,
        title: title,
        buttonActions: buttonActions,
        buttonTitles: buttonTitles
      )
    )
  }
}

// MARK: - PresentationMessagePopupModifier

private struct PresentationMessagePopupModifier<State, Action, ButtonAction>: ViewModifier {
  @StateObject var viewStore: ViewStore<PresentationState<State>, PresentationAction<Action>>
  let toDestinationState: (State) -> AlertState<ButtonAction>?
  let fromDestinationAction: (ButtonAction) -> Action

  func body(content: Content) -> some View {
    let id = viewStore._id
    let alertState = viewStore.wrappedValue.flatMap(toDestinationState)
    content.messagePopup(
      isPresented: Binding( // TODO: do proper binding
        get: { viewStore.wrappedValue.flatMap(toDestinationState) != nil },
        set: { newState in
          if !newState, viewStore.wrappedValue != nil, viewStore._id == id {
            viewStore.send(.dismiss)
          }
        }
      ),
      message: alertState?.message ?? TextState(""),
      title: alertState?.title ?? TextState(""),
      buttonActions: alertState?.buttons.map { button in
        switch button.action.type {
        case let .send(action):
          return { if let action { viewStore.send(.presented(self.fromDestinationAction(action))) } }
        case let .animatedSend(action, animation):
          return {
            if let action {
              _ = withAnimation(animation) {
                viewStore.send(.presented(self.fromDestinationAction(action)))
              }
            }
          }
        }
      } ?? [],
      buttonTitles: alertState?.buttons.map(\.label) ?? []
    )
  }
}

// MARK: - MessagePopupView

struct MessagePopupView: ViewModifier {
  @Binding var isPresented: Bool
  @State var expanding = false
  var message: TextState
  var title: TextState
  var buttonActions: [() -> Void]
  var buttonTitles: [TextState]

  func body(content: Content) -> some View {
    content
      .popover(
        present: $isPresented,
        attributes: {
          $0.blocksBackgroundTouches = true
          $0.rubberBandingMode = .none
          $0.position = .relative(
            popoverAnchors: [
              .center,
            ]
          )
          $0.presentation.animation = .easeOut(duration: 0.15)
          $0.dismissal.mode = .none
          $0.onTapOutside = {
            withAnimation(.easeIn(duration: 0.15)) {
              expanding = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              withAnimation(.easeOut(duration: 0.4)) {
                expanding = false
              }
            }
          }
        }
      ) {
        AlertViewPopover(
          present: $isPresented,
          expanding: $expanding,
          title: title,
          message: message,
          buttonActions: buttonActions,
          buttonTitles: buttonTitles
        )
      } background: {
        Color.black.opacity(0.1)
      }
  }
}

// MARK: - AlertViewPopover

struct AlertViewPopover: View {
  @Binding var present: Bool
  @Binding var expanding: Bool
  var title: TextState
  var message: TextState
  var buttonActions: [() -> Void]
  var buttonTitles: [TextState]

  /// the initial animation
  @State var scaled = true

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 6) {
        Text(title)
          .fontWeight(.medium)
          .multilineTextAlignment(.center)

        Text(message)
          .multilineTextAlignment(.center)
      }
      .padding()

      Divider()

      HStack {
        ForEach(0 ..< buttonTitles.count, id: \.self) { index in
          Button {
            buttonActions[index]()
          } label: {
            Text(buttonTitles[index])
              .foregroundColor(.blue)
          }
        }
      }
      .buttonStyle(Templates.AlertButtonStyle())
    }
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .popoverShadow(shadow: .system)
    .frame(width: 260)
    .scaleEffect(expanding ? 1.05 : 1)
    .scaleEffect(scaled ? 2 : 1)
    .opacity(scaled ? 0 : 1)
    .onAppear {
      withAnimation(.spring(
        response: 0.4,
        dampingFraction: 0.9,
        blendDuration: 1
      )) {
        scaled = false
      }
    }
  }
}

extension PresentationState {
  var _id: AnyHashable? {
    String(describing: wrappedValue)
  }
}
