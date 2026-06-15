import CryptoKit
import Foundation

public protocol WLStorageBacker<T> {
    associatedtype T: Codable & Sendable

    var key: String { get }

    func read(defaultValueClosure: () -> T) -> T

    func write(value: T)
}

public class WLStorageDefaultBacker<T: Codable & Sendable>: WLStorageBacker {
    public let key: String
    public let fileURL: URL?

    public init(key: String, directory: URL? = WLStorageDefaultBacker<T>.defaultDirectory) {
        self.key = key
        guard let directory else {
            fileURL = nil
            return
        }
        let filename = {
            let isSafeKey =
                !key.isEmpty &&
                key != "." &&
                key != ".." &&
                key.count <= 127 &&
                key.utf8.allSatisfy { byte in
                    (48 ... 57).contains(byte) || // 0-9
                        (65 ... 90).contains(byte) || // A-Z
                        (97 ... 122).contains(byte) || // a-z
                        byte == 45 || // -
                        byte == 46 || // .
                        byte == 95 // _
                }
            if isSafeKey {
                return key
            } else {
                return key.sha256
            }
        }()
        fileURL = directory.appending(component: filename, isDirectory: false)
    }

    public func read(defaultValueClosure: () -> T) -> T {
        func getExisting() -> T? {
            guard let fileURL else {
                // We assert only once in `directory`
                return nil
            }
            guard let data = try? Data(contentsOf: fileURL), data.count > 0 else {
                return nil
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                assertionFailure("[WLStorage] Read failed: \(error)")
                return nil
            }
        }
        guard let existing = getExisting() else {
            let fallback = defaultValueClosure()
            write(value: fallback)
            return fallback
        }
        return existing
    }

    public func write(value: T) {
        guard let fileURL else {
            // We assert only once in `directory`
            return
        }
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("[WLStorage] Write failed: \(error)")
        }
    }

    public static var defaultDirectory: URL? {
        guard let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            assertionFailure("[WLStorage] Document directory not found")
            return nil
        }
        #if DEBUG
            let debug_flag = "_debug"
        #else
            let debug_flag = ""
        #endif
        do {
            let url = documentDirectoryURL.appending(component: ".wlstorage\(debug_flag)", isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            assertionFailure("[WLStorage] Failed to create directory: \(error)")
            return nil
        }
    }
}

private extension URL {
    func appending(
        component: String,
        isDirectory: Bool
    ) -> URL {
        if #available(iOS 16, macOS 13, *) {
            return appending(
                component: component,
                directoryHint: isDirectory ? .isDirectory : .notDirectory
            )
        } else {
            return appendingPathComponent(
                component,
                isDirectory: isDirectory
            )
        }
    }
}

private extension String {
    var sha256: String {
        let data = Data(utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
