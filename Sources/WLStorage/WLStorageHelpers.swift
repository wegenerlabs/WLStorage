import CryptoKit
import Foundation

private let wl_storage_directory_url: URL = {
    guard let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        fatalError("[WLStorage] Document directory not found")
    }
    #if DEBUG
        let debug_flag = "_debug"
    #else
        let debug_flag = ""
    #endif
    let url = documentDirectoryURL.appending(component: ".wlstorage\(debug_flag)", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
        fatalError("[WLStorage] Failed to create directory: \(error)")
    }
    return url
}()

extension WLStorage {
    static func readFromDisk(fileURL: URL) -> T? {
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

    static func writeToDisk(fileURL: URL, value: T) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL)
            return true
        } catch {
            assertionFailure("[WLStorage] Write failed: \(error)")
            return false
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

extension String {
    var keyToFileURL: URL {
        let allowedCharacters = CharacterSet
            .alphanumerics
            .union(
                CharacterSet(charactersIn: "_-.")
            )
        let fileName: String
        if isEmpty || count > 127 || rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            fileName = sha256
        } else {
            fileName = self
        }
        return wl_storage_directory_url.appending(component: fileName, isDirectory: false)
    }

    private var sha256: String {
        let data = Data(utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
