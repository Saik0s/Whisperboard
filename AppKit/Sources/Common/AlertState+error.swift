import ComposableArchitecture

extension AlertState {
  static func error(_ error: Error) -> Self {
    Self(
      title: TextState("Something went wrong"),
      message: TextState(error.localizedDescription),
      buttons: []
    )
  }

  static func error(message: String) -> Self {
    Self(
      title: TextState("Something went wrong"),
      message: TextState(message),
      buttons: []
    )
  }

  static var genericError: Self {
    Self(
      title: TextState("Something went wrong"),
      message: TextState("Please try again later."),
      buttons: []
    )
  }
}
