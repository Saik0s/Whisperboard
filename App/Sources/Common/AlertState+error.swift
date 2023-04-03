import ComposableArchitecture

public extension AlertState {
  static func error(_ error: Error) -> Self {
    Self(
      title: TextState("Error"),
      message: TextState(error.localizedDescription),
      buttons: [ .default(TextState("OK")) ]
    )
  }
}
