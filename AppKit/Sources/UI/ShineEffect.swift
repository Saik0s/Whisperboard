import SwiftUI

// MARK: - ShineEffect

struct ShineEffect: ViewModifier {
  let isEnabled: Bool
  let animation: Animation
  let gradient: Gradient
  let bandArea: CGFloat

  private var min: CGFloat { 0 - bandArea }
  private var max: CGFloat { 1 + bandArea }
  private var startPoint: UnitPoint { didAppear ? .bottomTrailing : UnitPoint(x: min, y: min) }
  private var endPoint: UnitPoint { didAppear ? UnitPoint(x: max, y: max) : .topLeading }

  @State private var didAppear = false

  func body(content: Content) -> some View {
    content.mask {
      if isEnabled {
        LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint)
      }
    }
    .onAppear { didAppear = true }
    .animation(animation, value: didAppear)
  }
}

extension View {
  func shining(
    isEnabled: Bool = true,
    animation: Animation = .easeInOut(duration: 1.5).delay(0.25).repeatForever(autoreverses: false),
    gradient: Gradient = .init(colors: [.black.opacity(0.3), .black, .black.opacity(0.3)]),
    bandArea: CGFloat = 0.3
  ) -> some View {
    modifier(ShineEffect(isEnabled: isEnabled, animation: animation, gradient: gradient, bandArea: bandArea))
  }
}

// MARK: - ShiningCardEffect

struct ShiningCardEffect: ViewModifier {
  let isEnabled: Bool
  let animation: Animation
  let gradient: Gradient
  let defaultDegrees: Double
  let triggerDegrees: Double
  let bandArea: CGFloat
  let isTapped: Binding<Bool>?

  @State private var isHovering = false
  @GestureState private var isGestureTapped = false

  var isReallyTapped: Bool {
    isTapped?.wrappedValue ?? false
  }
  var isTriggered: Bool {
    (isHovering || isReallyTapped) && isEnabled
  }

  private var min: CGFloat { 0 - bandArea }
  private var max: CGFloat { 1 + bandArea }
  private var startPoint: UnitPoint { isTriggered ? .bottomTrailing : UnitPoint(x: min, y: min) }
  private var endPoint: UnitPoint { isTriggered ? UnitPoint(x: max, y: max) : .topLeading }

  func body(content: Content) -> some View {
    let tapGesture = DragGesture(minimumDistance: 0).updating($isGestureTapped) { _, isGestureTapped, _ in
      isGestureTapped = true
    }

    content.overlay(
      Rectangle()
        .fill(Color.white)
        .mask(
          LinearGradient(
            gradient: gradient,
            startPoint: startPoint,
            endPoint: endPoint
          )
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .rotation3DEffect(
      .degrees(isTriggered ? triggerDegrees : defaultDegrees),
      axis: (x: 1, y: -1, z: 0)
    )
    .onHover { isHovering = $0 }
    .animation(animation, value: isTriggered)
    .applyIf(isTapped == nil) {
      $0.simultaneousGesture(tapGesture)
    }
  }
}

extension View {
  func shiningCard(
    isEnabled: Bool = true,
    animation: Animation = .interpolatingSpring(),
    gradient: Gradient = Gradient(colors: [Color.clear, .black.opacity(0.5), Color.clear]),
    defaultDegrees: Double = 8,
    triggerDegrees: Double = -8,
    bandArea: CGFloat = 0.3,
    isTapped: Binding<Bool>? = nil
  ) -> some View {
    modifier(ShiningCardEffect(
      isEnabled: isEnabled,
      animation: animation,
      gradient: gradient,
      defaultDegrees: defaultDegrees,
      triggerDegrees: triggerDegrees,
      bandArea: bandArea,
      isTapped: isTapped
    ))
  }
}

#if DEBUG
  struct Shine_Previews: PreviewProvider {
    static var previews: some View {
      let loremText = Text(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec auctor, nisl quis tincidunt ultricies, nunc nisl aliquam nunc, quis aliquam nisl nunc quis nisl. Donec auctor, nisl quis tincidunt ultricies, nunc nisl aliquam nunc, quis aliquam nisl nunc quis nisl."
      )
      let profilePic = Image(systemName: "person.crop.circle")
        .resizable()
        .frame(width: 100, height: 100)

      VStack(alignment: .leading) {
        HStack {
          profilePic
          VStack(alignment: .leading) {
            Text("John Doe").font(.title).fontWeight(.bold)
            Text("iOS Developer").font(.subheadline)
          }
        }
        .shining()

        Text("About").font(.title).fontWeight(.bold)
          .shining()
        loremText
          .shining()
        Text("Skills").font(.title).fontWeight(.bold)
          .shining()
        HStack {
          Text("Swift")
            .shining()
          Text("Objective-C")
            .shining()
          Text("C++")
            .shining()
        }

        loremText
          .redacted(reason: .placeholder)
          .shining()
      }
      .previewBasePreset()

      VStack(alignment: .leading) {
        HStack {
          profilePic
          VStack(alignment: .leading) {
            Text("John Doe").font(.title).fontWeight(.bold)
            Text("iOS Developer").font(.subheadline)
          }
        }

        Text("About").font(.title).fontWeight(.bold)
        loremText
        Text("Skills").font(.title).fontWeight(.bold)
        HStack {
          Text("Swift")
          Text("Objective-C")
          Text("C++")
        }

        loremText
          .redacted(reason: .placeholder)
      }
      .shining()
      .previewBasePreset()

      VStack(alignment: .leading) {
        HStack {
          profilePic
          VStack(alignment: .leading) {
            Text("John Doe").font(.title).fontWeight(.bold)
            Text("iOS Developer").font(.subheadline)
          }
        }
        .shining()

        VStack(alignment: .leading) {
          Text("About").font(.title).fontWeight(.bold)
          loremText
        }
        .shining()
        VStack(alignment: .leading) {
          Text("Skills").font(.title).fontWeight(.bold)
          HStack {
            Text("Swift")
            Text("Objective-C")
            Text("C++")
          }
        }
        .shining()

        loremText
          .redacted(reason: .placeholder)
          .shining()
      }
      .previewBasePreset()

      VStack(alignment: .leading) {
        VStack {
          profilePic
          VStack(alignment: .leading) {
            Text("John Doe").font(.title).fontWeight(.bold)
            Text("iOS Developer").font(.subheadline)
          }
        }
        .padding()
        HStack {
          VStack {
            profilePic
            VStack(alignment: .leading) {
              Text("John Doe").font(.title).fontWeight(.bold)
              Text("iOS Developer").font(.subheadline)
            }
          }
          .padding()
          .shiningCard()

          VStack {
            profilePic
            VStack(alignment: .leading) {
              Text("John Doe").font(.title).fontWeight(.bold)
              Text("iOS Developer").font(.subheadline)
            }
          }
          .padding()
          .shiningCard(defaultDegrees: 0, triggerDegrees: -8)
        }

        loremText
          .redacted(reason: .placeholder)
          .shiningCard()
      }
      .previewBasePreset()
    }
  }
#endif
