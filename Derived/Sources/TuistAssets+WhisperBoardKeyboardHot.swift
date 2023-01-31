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
public enum WhisperBoardKeyboardHotAsset {
  public static let whisperIcon = WhisperBoardKeyboardHotImages(name: "whisper_icon")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

public struct WhisperBoardKeyboardHotImages {
  public fileprivate(set) var name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  public typealias Image = UIImage
  #endif

  public var image: Image {
    let bundle = WhisperBoardKeyboardHotResources.bundle
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

public extension WhisperBoardKeyboardHotImages.Image {
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the WhisperBoardKeyboardHotImages.image property")
  convenience init?(asset: WhisperBoardKeyboardHotImages) {
    #if os(iOS) || os(tvOS)
    let bundle = WhisperBoardKeyboardHotResources.bundle
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
  init(asset: WhisperBoardKeyboardHotImages) {
    let bundle = WhisperBoardKeyboardHotResources.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: WhisperBoardKeyboardHotImages, label: Text) {
    let bundle = WhisperBoardKeyboardHotResources.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: WhisperBoardKeyboardHotImages) {
    let bundle = WhisperBoardKeyboardHotResources.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:enable all
// swiftformat:enable all
