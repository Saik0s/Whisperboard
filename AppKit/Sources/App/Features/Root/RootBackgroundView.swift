import Inject
import Popovers
import SwiftUI

// MARK: - GooeyBlobsView

struct RootBackgroundView: View {
  @State var blobs: [Blob] = (1 ... 12).map { _ in
    Blob(
      position: CGPoint(x: CGFloat.random(in: 0 ..< 1), y: CGFloat.random(in: 0 ..< 1)),
      radius: CGFloat.random(in: 100 ... 200)
    )
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ForEach(blobs.indices, id: \.self) { i in
          BlobView(position: $blobs[i].position, radius: blobs[i].radius)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
              moveBlob(index: i, within: geometry.size)
            }
        }
        .blur(radius: 100)

        Templates.VisualEffectView(.systemChromeMaterialDark)

        Rectangle()
          .fill(Color(white: 0.6))
          .blendMode(.colorDodge)
          .allowsHitTesting(false)

        Rectangle()
          .fill(Color.DS.Background.primary)
          .blendMode(.luminosity)
          .allowsHitTesting(false)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .edgesIgnoringSafeArea(.all)
    }
    .compositingGroup()
    .enableInjection()
  }

  func moveBlob(index: Int, within size: CGSize) {
    let targetPos = CGPoint(x: CGFloat.random(in: 0 ..< 1), y: CGFloat.random(in: 0 ..< 1))
    withAnimation(.spring().speed(0.1)) {
      blobs[index].position = CGPoint(x: targetPos.x * size.width, y: targetPos.y * size.height)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      moveBlob(index: index, within: size)
    }
  }

  @ObserveInjection var inject
}

// MARK: - BlobView

struct BlobView: View {
  @Binding var position: CGPoint
  let radius: CGFloat

  var body: some View {
    Circle()
      .fill(RadialGradient.purpleSpotlight)
      .frame(width: radius, height: radius)
      .position(position)
  }
}

// MARK: - Blob

struct Blob: Identifiable, Equatable {
  let id = UUID()
  var position: CGPoint
  var radius: CGFloat
}
