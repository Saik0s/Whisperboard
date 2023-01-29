// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
public enum WhisperBoardKeyboardAsset {
  public static let whisperIcon = WhisperBoardKeyboardImages(name: "whisper_icon")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

public struct WhisperBoardKeyboardImages {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Image = UIImage
  #endif

  public var image: Image {
    let bundle = WhisperBoardKeyboardResources.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let image = bundle.image(forResource: NSImage.Name(name))
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  public var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

public extension WhisperBoardKeyboardImages.Image {
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the WhisperBoardKeyboardImages.image property")
  convenience init?(asset: WhisperBoardKeyboardImages) {
    #if os(iOS) || os(tvOS)
    let bundle = WhisperBoardKeyboardResources.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Image {
  init(asset: WhisperBoardKeyboardImages) {
    let bundle = WhisperBoardKeyboardResources.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: WhisperBoardKeyboardImages, label: Text) {
    let bundle = WhisperBoardKeyboardResources.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: WhisperBoardKeyboardImages) {
    let bundle = WhisperBoardKeyboardResources.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:enable all
// swiftformat:enable all
