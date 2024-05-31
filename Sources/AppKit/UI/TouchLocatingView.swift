import SwiftUI
import UIKit

// MARK: - TouchLocatingView

/// Our UIKit to SwiftUI wrapper view
struct TouchLocatingView: UIViewRepresentable {
  /// The types of touches users want to be notified about
  struct TouchType: OptionSet {
    let rawValue: Int

    static let started = Self(rawValue: 1 << 0)
    static let moved = Self(rawValue: 1 << 1)
    static let ended = Self(rawValue: 1 << 2)
    static let all: TouchType = [.started, .moved, .ended]
  }

  /// A closure to call when touch data has arrived
  var onUpdate: (CGPoint) -> Void

  /// The list of touch types to be notified of
  var types = TouchType.all

  /// Whether touch information should continue after the user's finger has left the view
  var limitToBounds = true

  func makeUIView(context _: Context) -> TouchLocatingUIView {
    // Create the underlying UIView, passing in our configuration
    let view = TouchLocatingUIView()
    view.onUpdate = onUpdate
    view.touchTypes = types
    view.limitToBounds = limitToBounds
    return view
  }

  func updateUIView(_: TouchLocatingUIView, context _: Context) {}

  /// The internal UIView responsible for catching taps
  class TouchLocatingUIView: UIView {
    /// Internal copies of our settings
    var onUpdate: ((CGPoint) -> Void)?
    var touchTypes: TouchLocatingView.TouchType = .all
    var limitToBounds = true

    /// Our main initializer, making sure interaction is enabled.
    override init(frame: CGRect) {
      super.init(frame: frame)
      isUserInteractionEnabled = true
    }

    /// Just in case you're using storyboards!
    required init?(coder: NSCoder) {
      super.init(coder: coder)
      isUserInteractionEnabled = true
    }

    /// Triggered when a touch starts.
    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
      guard let touch = touches.first else { return }
      let location = touch.location(in: self)
      send(location, forEvent: .started)
    }

    /// Triggered when an existing touch moves.
    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
      guard let touch = touches.first else { return }
      let location = touch.location(in: self)
      send(location, forEvent: .moved)
    }

    /// Triggered when the user lifts a finger.
    override func touchesEnded(_ touches: Set<UITouch>, with _: UIEvent?) {
      guard let touch = touches.first else { return }
      let location = touch.location(in: self)
      send(location, forEvent: .ended)
    }

    /// Triggered when the user's touch is interrupted, e.g. by a low battery alert.
    override func touchesCancelled(_ touches: Set<UITouch>, with _: UIEvent?) {
      guard let touch = touches.first else { return }
      let location = touch.location(in: self)
      send(location, forEvent: .ended)
    }

    /// Send a touch location only if the user asked for it
    func send(_ location: CGPoint, forEvent event: TouchLocatingView.TouchType) {
      guard touchTypes.contains(event) else {
        return
      }

      if limitToBounds == false || bounds.contains(location) {
        onUpdate?(CGPoint(x: round(location.x), y: round(location.y)))
      }
    }
  }
}

// MARK: - TouchLocator

/// A custom SwiftUI view modifier that overlays a view with our UIView subclass.
struct TouchLocator: ViewModifier {
  var type: TouchLocatingView.TouchType = .all
  var limitToBounds = true
  let perform: (CGPoint) -> Void

  func body(content: Content) -> some View {
    content
      .overlay(
        TouchLocatingView(onUpdate: perform, types: type, limitToBounds: limitToBounds)
      )
  }
}

/// A new method on View that makes it easier to apply our touch locater view.
extension View {
  func onTouch(type: TouchLocatingView.TouchType = .all, limitToBounds: Bool = true, perform: @escaping (CGPoint) -> Void) -> some View {
    modifier(TouchLocator(type: type, limitToBounds: limitToBounds, perform: perform))
  }
}

// MARK: - TouchLocationPercentageModifier

struct TouchLocationPercentageModifier: ViewModifier {
  @State var horizontalPart: Double = 0
  @State var verticalPart: Double = 0
  var type: TouchLocatingView.TouchType = .all
  var limitToBounds = true
  var perform: (_ horizontal: Double, _ vertical: Double) -> Void

  func body(content: Content) -> some View {
    content
      .overlay {
        GeometryReader { proxy in
          Color.clear
            .onTouch(type: type, limitToBounds: limitToBounds) { location in
              horizontalPart = Double(location.x / proxy.size.width)
              verticalPart = Double(location.y / proxy.size.height)
              perform(horizontalPart, verticalPart)
            }
        }
      }
  }
}

extension View {
  func onTouchLocationPercent(
    type: TouchLocatingView.TouchType = .all,
    limitToBounds: Bool = true,
    perform: @escaping (_ horizontal: Double, _ vertical: Double) -> Void
  ) -> some View {
    modifier(TouchLocationPercentageModifier(type: type, limitToBounds: limitToBounds, perform: perform))
  }
}

// MARK: - ContentView

/// Finally, here's some example code you can try out.
struct ContentView: View {
  var body: some View {
    VStack {
      Text("This will track all touches, inside bounds only.")
        .padding()
        .background(.red)
        .onTouch(perform: updateLocation)

      Text("This will track all touches, ignoring bounds – you can start a touch inside, then carry on moving it outside.")
        .padding()
        .background(.blue)
        .onTouch(limitToBounds: false, perform: updateLocation)

      Text("This will track only starting touches, inside bounds only.")
        .padding()
        .background(.green)
        .onTouch(type: .started, perform: updateLocation)
    }
  }

  func updateLocation(_ location: CGPoint) {
    print(location)
  }
}
