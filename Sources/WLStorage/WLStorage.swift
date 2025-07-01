#if !targetEnvironment(macCatalyst) && canImport(AppKit)
    import AppKit
#endif
import Combine
import Foundation
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

@propertyWrapper
public final class WLStorage<T: Codable & Sendable>: ObservableObject, @unchecked Sendable {
    public let key: String
    private let memoryQueue: DispatchQueue
    private var memoryValue: T
    private var flushPending = false
    private let flushPublisher = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    public let objectWillChange = ObservableObjectPublisher()

    public init(key: String, defaultValueClosure: () -> T) {
        self.key = key
        memoryQueue = DispatchQueue(
            label: "com.wegenerlabs.WLStorage.\(key).memory",
            qos: .userInitiated
        )
        memoryValue = {
            if let diskValue: T = WLStorage<T>.readFromDisk(key: key) {
                return diskValue
            } else {
                let defaultValue = defaultValueClosure()
                _ = WLStorage<T>.writeToDisk(key: key, value: defaultValue)
                return defaultValue
            }
        }()
        let flushQueue = DispatchQueue(
            label: "com.wegenerlabs.WLStorage.\(key).flush",
            qos: .userInitiated
        )
        flushPublisher
            .throttle(for: .seconds(1), scheduler: flushQueue, latest: true)
            .sink { [weak self] _ in
                self?.flush()
            }
            .store(in: &cancellables)
        #if !targetEnvironment(macCatalyst) && canImport(AppKit)
            NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
                .sink { [weak self] _ in
                    self?.flush()
                }
                .store(in: &cancellables)
        #endif
        #if canImport(UIKit)
            NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
                .sink { [weak self] _ in
                    self?.flush()
                }
                .store(in: &cancellables)
            NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
                .sink { [weak self] _ in
                    self?.flush()
                }
                .store(in: &cancellables)
        #endif
    }

    public convenience init(key: String, defaultValue: T) {
        self.init(key: key, defaultValueClosure: { defaultValue })
    }

    public var wrappedValue: T {
        get {
            memoryQueue.sync {
                memoryValue
            }
        } set {
            objectWillChange.send()
            memoryQueue.sync {
                memoryValue = newValue
                flushPending = true
                flushPublisher.send(())
            }
        }
    }

    public var binding: Binding<T> {
        return Binding(get: { self.wrappedValue }, set: { self.wrappedValue = $0 })
    }

    public func flush() {
        memoryQueue.sync {
            if flushPending, WLStorage<T>.writeToDisk(key: key, value: memoryValue) {
                flushPending = false
            }
        }
    }

    deinit {
        flush()
    }
}

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

private extension WLStorage {
    private static func fileURL(key: String) -> URL {
        wl_storage_directory_url.appending(component: key, isDirectory: false)
    }

    static func readFromDisk(key: String) -> T? {
        guard let data = try? Data(contentsOf: fileURL(key: key)), data.count > 0 else {
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            assertionFailure("[WLStorage] Read failed: \(error)")
            return nil
        }
    }

    static func writeToDisk(key: String, value: T) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL(key: key))
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
