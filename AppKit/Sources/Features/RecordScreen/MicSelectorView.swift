
import AVFoundation
import ComposableArchitecture
import Inject
import SwiftUI

// MARK: - MicSelector

struct MicSelector: ReducerProtocol {
  struct State: Equatable {
    var mics: [Microphone] = []

    var currentMic: Microphone?

    @PresentationState var alert: AlertState<Action.Alert>?
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case task
    case micsUpdated([Microphone])
    case checkCurrentMic
    case setCurrentMic(Microphone?)
    case micSelected(Microphone)
    case errorWhileSettingMic(EquatableErrorWrapper)
    case alert(PresentationAction<Alert>)

    enum Alert: Equatable {}
  }

  @Dependency(\.audioRecorder) var audioRecorder: AudioRecorderClient

  var body: some ReducerProtocol<State, Action> {
    BindingReducer()

    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        return .run { send in
          for await mics in try await audioRecorder.availableMicrophones() {
            log.debug(mics)
            await send(.micsUpdated(mics))
          }
        } catch: { error, send in
          log.error(error)
          await send(.errorWhileSettingMic(error.equatable))
        }

      case let .micsUpdated(mics):
        state.mics = mics
        return .send(.checkCurrentMic)

      case .checkCurrentMic:
        return .run { send in
          let mic = try await audioRecorder.currentMicrophone()
          await send(.setCurrentMic(mic))
        } catch: { error, send in
          log.error(error)
          await send(.errorWhileSettingMic(error.equatable))
        }

      case let .setCurrentMic(mic):
        state.currentMic = mic
        return .none

      case let .micSelected(mic):
        return .run { send in
          try await audioRecorder.setMicrophone(mic)
          await send(.setCurrentMic(mic))
        } catch: { error, send in
          log.error(error)
          await send(.errorWhileSettingMic(error.equatable))
        }

      case let .errorWhileSettingMic(error):
        state.alert = .error(error)
        return .none

      case .binding:
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: /Action.alert)
  }
}

// MARK: - MicSelectorView

struct MicSelectorView: View {
  @ObserveInjection var inject

  let store: StoreOf<MicSelector>

  init(store: StoreOf<MicSelector>) {
    self.store = store
  }

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      VStack(spacing: 0) {
        ForEach(viewStore.mics, id: \.id) { mic in
          Button(action: { viewStore.send(.micSelected(mic)) }) {
            HStack(spacing: .grid(2)) {
              let isSelected = mic.id == viewStore.currentMic?.id
              Image(systemName: "checkmark")
                .font(.DS.bodyS)
                .foregroundColor(.DS.Text.success)
                .hidden(!isSelected)

              VStack(alignment: .leading, spacing: 0) {
                Text(mic.port.portName)
                  .font(.DS.bodyS)
                  .foregroundColor(.DS.Text.base)
              }
            }
            .padding(.grid(2))
          }

          if mic.id != viewStore.mics.last?.id {
            Divider()
          }
        }
      }
      .fixedSize(horizontal: true, vertical: false)
      .alert(
        store: store.scope(state: \.$alert, action: { .alert($0) })
      )
      .task { viewStore.send(.task) }
    }
    .enableInjection()
  }
}

#if DEBUG
  struct MicSelectorView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        MicSelectorView(
          store: Store(
            initialState: MicSelector.State(),
            reducer: { MicSelector() }
          )
        )
      }
    }
  }
#endif
