//
// Created by Igor Tarasenko on 24/12/2022.
//

import Foundation
import Dependencies
import XCTestDynamicOverlay
import AVFoundation
import ComposableArchitecture

// struct WhisperInfo: Identifiable, Codable, Hashable {
//   var id: URL { fileURL }
//   let fileURL: URL
//   let text: String
//
//   var date: Date {
//     fileURL
//       .lastPathComponent
//       .split(separator: ".")
//       .first
//       .map { fileNameDateFormatter.date(from: "\($0)") }
//       .flatMap({ $0 })
//       ?? Date()
//   }
//
//   var duration: Double {
//     let asset = AVURLAsset(url: fileURL, options: nil)
//
//     let semaphore = DispatchSemaphore(value: 0)
//
//     class Box<T> {
//       var value: T
//       init(value: T) { self.value = value }
//     }
//
//     let boxedDuration = Box<Double>(value: 0)
//     Task {
//       let (duration, _) = try await asset.load(.duration, .metadata)
//       boxedDuration.value = Double(duration.value) / Double(duration.timescale)
//       semaphore.signal()
//     }
//
//     semaphore.wait()
//     return boxedDuration.value
//   }
//
//   var asWhisper: Whisper.State {
//     Whisper.State(date: date, duration: duration, url: fileURL)
//   }
// }

typealias WhisperInfo = Whisper.State

struct Storage {
  var read: @Sendable () async throws -> IdentifiedArrayOf<WhisperInfo>
  var write: @Sendable (IdentifiedArrayOf<WhisperInfo>) async throws -> Void
  var cleanup: @Sendable () async throws -> Void
  var createNewWhisperURL: () -> URL
  var fileURLWithName: (String) -> URL
}

extension Storage: TestDependencyKey {
  static let previewValue = Self(
    read: {
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 5)
      return []
    },
    write: { _ in },
    cleanup: {},
    createNewWhisperURL: { URL(filePath: "") },
    fileURLWithName: { _ in URL(filePath: "") }
  )

  static let testValue = Self(
    read: unimplemented("\(Self.self).read"),
    write: unimplemented("\(Self.self).write"),
    cleanup: unimplemented("\(Self.self).cleanup"),
    createNewWhisperURL: unimplemented("\(Self.self).createNewWhisperURL"),
    fileURLWithName: unimplemented("\(Self.self).fileURLWithName")
  )
}

extension Storage: DependencyKey {
  static let liveValue: Self = {
    let docURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

    @Sendable func read() async throws -> IdentifiedArrayOf<WhisperInfo> {
      log("Reading stored whispers")
      guard let data = UserDefaults.standard.object(forKey: "whispers") as? Data else { return [] }
      let whispers = try JSONDecoder().decode([WhisperInfo].self, from: data).identifiedArray
      let filtered = whispers.filter { whisper in
        FileManager.default.fileExists(atPath: docURL.appending(path: whisper.fileName).path)
      }
      log("whispers:", whispers.count, "filtered:", filtered.count)
      return filtered
    }

    @Sendable func write(_ whispers: IdentifiedArrayOf<WhisperInfo>) async throws {
      log("writing \(whispers.count) whispers to storage")
      let filtered = whispers.filter { whisper in
        FileManager.default.fileExists(atPath: docURL.appending(path: whisper.fileName).path)
      }
      let data = try JSONEncoder().encode(filtered.elements)
      UserDefaults.standard.set(data, forKey: "whispers")
    }

    return Self(
      read: {
        try await read()
      },
      write: { whispers in
        try await write(whispers)
      },
      cleanup: {
        let content = try FileManager.default.contentsOfDirectory(atPath: docURL.path)
        let whispers = try await read()
        try content.forEach { name in
          if whispers.contains(where: { whisper in whisper.fileName == name }) == false {
            let fileURL = docURL.appending(path: name)
            log("Removing file", fileURL)
            try FileManager.default.removeItem(at: fileURL)
          }
        }
        try await write(whispers.filter { whisper in
          FileManager.default.fileExists(atPath: docURL.appending(path: whisper.fileName).path)
        })
      },
      createNewWhisperURL: {
        let filename = fileNameDateFormatter.string(from: Date()) + ".wav"
        let url = docURL.appending(path: filename)
        log("New file url", url)
        return url
      },
      fileURLWithName: { name in
        docURL.appending(path: name)
      }
    )
  }()
}

extension DependencyValues {
  var storage: Storage {
    get { self[Storage.self] }
    set { self[Storage.self] = newValue }
  }
}
