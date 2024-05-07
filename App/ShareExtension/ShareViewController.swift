import AudioKit
import AVFoundation
import Foundation
import MobileCoreServices
import Social
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - ShareError

enum ShareError: Error, LocalizedError {
  case somethingWentWrong

  var errorDescription: String? {
    switch self {
    case .somethingWentWrong:
      "Something went wrong."
    }
  }
}

// MARK: - ShareViewController

/// This Share Extension handles incoming audio files.
/// It processes the input items, saves them to a shared container, and opens the main app with a URL containing serialized data.
/// The main app then accesses the shared container to retrieve the saved files.
@objc(ShareExtensionViewController)
final class ShareViewController: UIViewController {
  private let appURL = URL(string: "whisperboard://share")

  private lazy var viewModel: ShareViewModel? = {
    let appGroupName = "group.whisperboard"

    guard let groupFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) else {
      return nil
    }

    let sharedFolderURL = groupFolderURL.appending(component: "share")
    return ShareViewModel(sharedFolderURL: sharedFolderURL)
  }()

  private var hostingController: UIViewController?

  override func viewDidLoad() {
    super.viewDidLoad()

    viewModel?.closeButtonTapped = { [extensionContext] in
      extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    viewModel?.openAppButtonTapped = { [weak self, appURL] in
      guard let appURL else { return }
      self?.openURL(appURL)
    }

    viewModel?.cancelExportButtonTapped = { [extensionContext] in
      extensionContext?.cancelRequest(withError: NSError(domain: "me.igortarasenko.whisperboard", code: 0, userInfo: nil))
    }

    if let viewModel {
      hostingController = UIHostingController(rootView: ShareView(viewModel: viewModel))
    } else {
      hostingController = UIHostingController(rootView: ErrorView { [weak self] in
        self?.extensionContext?.cancelRequest(withError: NSError(domain: "me.igortarasenko.whisperboard", code: 0, userInfo: nil))
      })
    }

    if let hostingController {
      addChild(hostingController)
      view.addSubview(hostingController.view)
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
        hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
      hostingController.didMove(toParent: self)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if let extensionContext {
      Task { @MainActor in
        await viewModel?.processInputItems(extensionContext: extensionContext)
      }
    } else {
      extensionContext?.cancelRequest(withError: NSError(domain: "me.igortarasenko.whisperboard", code: 0, userInfo: nil))
    }
  }

  @objc
  @discardableResult
  private func openURL(_ url: URL) -> Bool {
    var responder: UIResponder? = self
    while responder != nil {
      if let application = responder as? UIApplication {
        return application.perform(#selector(openURL(_:)), with: url) != nil
      }
      responder = responder?.next
    }
    return false
  }
}

// MARK: - ErrorView

struct ErrorView: View {
  var onClose: () -> Void

  var body: some View {
    ZStack {
      AnimatedGradientBackground()

      VStack(spacing: 16) {
        Text("Something went wrong")
      }
      .foregroundColor(.white)
      .font(.title)
      .multilineTextAlignment(.center)

      HStack(spacing: 16) {
        Button("Close", action: onClose)
      }
      .padding(.bottom, 24)
      .primaryButtonStyle()
    }
  }
}

// MARK: - ShareView

struct ShareView: View {
  @ObservedObject var viewModel: ShareViewModel

  var body: some View {
    ZStack {
      AnimatedGradientBackground()

      if viewModel.isProcessing {
        ZStack {
          ProgressView()

          Button("Cancel") {
            viewModel.cancelExportButtonTapped?()
          }
          .padding(.bottom, 24)
          .frame(maxHeight: .infinity, alignment: .bottom)
        }
      } else {
        ZStack {
          VStack(spacing: 16) {
            if viewModel.isSuccess {
              Text("Done!")
                .transition(.push(from: .top))
              ForEach(viewModel.sharedFileNames, id: \.self) { fileName in
                Text(fileName)
                  .transition(.push(from: .top))
                  .font(.body)
              }
            } else {
              if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
              } else {
                Text("Something went wrong")
              }
            }
          }
          .padding()
          .foregroundColor(.white)
          .font(.title.italic())
          .multilineTextAlignment(.center)

          HStack(spacing: 16) {
            Button("Close") {
              viewModel.closeButtonTapped?()
            }
            if viewModel.isSuccess {
              Button("Open App") {
                viewModel.openAppButtonTapped?()
              }
            }
          }
          .padding(.bottom, 24)
          .frame(maxHeight: .infinity, alignment: .bottom)
        }
      }
    }
    .primaryButtonStyle()
    .animation(.default, value: viewModel.state)
  }
}

// MARK: - ShareViewModel

@MainActor
class ShareViewModel: ObservableObject {
  enum State: Equatable { case processing, failed(String), success }

  let sharedFolderURL: URL

  @Published var state: State = .processing

  var closeButtonTapped: (() -> Void)?
  var openAppButtonTapped: (() -> Void)?
  var cancelExportButtonTapped: (() -> Void)?

  init(sharedFolderURL: URL) {
    self.sharedFolderURL = sharedFolderURL
  }

  var isProcessing: Bool { state == .processing }
  var isSuccess: Bool { state == .success }
  var errorMessage: String? {
    if case let .failed(message) = state { return message }
    return nil
  }

  @Published var sharedFileNames: [String] = []

  func presentErrorAlert(for error: ShareError) {
    state = .failed(error.localizedDescription)
  }

  func processInputItems(extensionContext: NSExtensionContext) async {
    do {
      try setupSharedContainer()

      let itemsAttachments = extensionContext.inputItems
        .compactMap { $0 as? NSExtensionItem }
        .compactMap(\.attachments)
        .flatMap { $0 }

      for itemProvider in itemsAttachments where itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        let url: URL = try await withCheckedThrowingContinuation { continuation in
          itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { url, error in
            guard error == nil, let url = url as? URL else {
              continuation.resume(throwing: error ?? ShareError.somethingWentWrong)
              return
            }
            continuation.resume(returning: url)
          }
        }

        try await handleLoadedData(url)
      }
      state = .success
    } catch {
      print("\(#filePath):\(#line)", error.localizedDescription)
      presentErrorAlert(for: ShareError.somethingWentWrong)
    }
  }

  private func setupSharedContainer() throws {
    try FileManager.default.createDirectory(at: sharedFolderURL, withIntermediateDirectories: true, attributes: nil)
    let files = try FileManager.default.contentsOfDirectory(atPath: sharedFolderURL.path)
    print("Files in shared container: \(files)")
  }

  private func handleLoadedData(_ currentURL: URL) async throws {
    print("Found URL \(currentURL)")
    let audioFileName = currentURL.pathComponents.last ?? newFileName()
    var newURL = sharedFolderURL.appending(component: audioFileName).deletingPathExtension().appendingPathExtension("wav")
    while FileManager.default.fileExists(atPath: newURL.path) {
      newURL = sharedFolderURL.appending(component: newURL.deletingPathExtension().lastPathComponent + "_1").appendingPathExtension("wav")
    }
    try await importFile(currentURL, newURL)
    sharedFileNames.append(newURL.deletingPathExtension().lastPathComponent)
  }

  private func newFileName() -> String {
    UUID().uuidString + ".m4a"
  }

  func importFile(_ from: URL, _ to: URL) async throws {
    print("Importing file from \(from) to \(to)")
    var options = FormatConverter.Options()
    options.format = .wav
    options.sampleRate = 16000
    options.bitDepth = 24
    options.channels = 1

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      let converter = FormatConverter(inputURL: from, outputURL: to, options: options)
      converter.start { error in
        DispatchQueue.main.async {
          if let error {
            print("Error converting file: \(error.localizedDescription)")
            continuation.resume(throwing: error)
          } else {
            print("File converted successfully")
            continuation.resume()
          }
        }
      }
    }
  }
}

// MARK: - AnimatedGradientBackground

struct AnimatedGradientBackground: View {
  @State private var animation = false

  let colors: [Color] = [
    Color(red: 0.1, green: 0.1, blue: 0.3),
    Color(red: 0.2, green: 0.1, blue: 0.4),
    Color(red: 0.3, green: 0.1, blue: 0.5),
    Color(red: 0.2, green: 0.1, blue: 0.4),
    Color(red: 0.1, green: 0.1, blue: 0.3),
  ]

  var body: some View {
    ZStack {
      LinearGradient(
        gradient: Gradient(colors: colors),
        startPoint: .bottomTrailing,
        endPoint: .topLeading
      )
      .opacity(animation ? 1 : 0)

      LinearGradient(
        gradient: Gradient(colors: colors),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .opacity(animation ? 0 : 1)

      Color.black.opacity(0.1)
    }
    .animation(
      Animation.easeInOut(duration: 3)
        .repeatForever(autoreverses: false),
      value: animation
    )
    .onAppear { animation.toggle() }
    .edgesIgnoringSafeArea(.all)
  }
}

// MARK: - PrimaryButtonStyle

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundColor(Color.white)
      .shadow(color: .black.opacity(0.4), radius: 1)
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
      .background {
        ZStack {
          Color.black

          LinearGradient(
            gradient: Gradient(colors: [
              Color(.systemBlue),
              Color(.systemBlue).opacity(0.8),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .opacity(configuration.isPressed ? 0 : 1)

          LinearGradient(
            gradient: Gradient(colors: [
              Color(.systemBlue),
              Color(.systemBlue).opacity(0.8),
              Color(.systemBlue).opacity(0.6),
            ]),
            startPoint: .bottomTrailing,
            endPoint: .topLeading
          )
          .opacity(configuration.isPressed ? 1 : 0)
        }
        .cornerRadius(8)
        .shadow(color: Color(.systemBlue).opacity(configuration.isPressed ? 0.2 : 0.7), radius: 8, x: 0, y: 0)
      }
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: configuration.isPressed)
  }
}

extension View {
  func primaryButtonStyle() -> some View {
    buttonStyle(PrimaryButtonStyle())
  }
}

// MARK: - NSItemProviderError

enum NSItemProviderError: Swift.Error {
  case dataIsNotExtractable(UTType)
}

extension NSItemProvider {
  func loadData<T>(for type: UTType, _: T.Type = T.self) async throws -> T {
    guard let data = try await loadItem(forTypeIdentifier: type.identifier, options: nil) as? T else {
      throw NSItemProviderError.dataIsNotExtractable(type)
    }
    return data
  }
}
