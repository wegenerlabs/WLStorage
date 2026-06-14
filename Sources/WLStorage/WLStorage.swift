#if !targetEnvironment(macCatalyst) && canImport(AppKit)
    import AppKit
#endif
import Combine
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

@propertyWrapper
public final class WLStorage<T: Codable & Sendable>: ObservableObject {
    public let key: String
    public let fileURL: URL
    private let memoryQueue: DispatchQueue
    private var memoryValue: T
    private var flushPending = false
    private let flushPublisher = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    public let objectWillChange = ObservableObjectPublisher()

    public init(key: String, defaultValueClosure: () -> T, flushInterval: Int? = 1) {
        self.key = key
        let fileURL = key.keyToFileURL
        self.fileURL = fileURL
        memoryQueue = DispatchQueue(
            label: "com.wegenerlabs.WLStorage.\(key).memory",
            qos: .userInitiated
        )
        memoryValue = {
            if let diskValue: T = WLStorage<T>.readFromDisk(fileURL: fileURL) {
                return diskValue
            } else {
                let defaultValue = defaultValueClosure()
                WLStorage<T>.writeToDisk(fileURL: fileURL, value: defaultValue)
                return defaultValue
            }
        }()
        let flushQueue = DispatchQueue(
            label: "com.wegenerlabs.WLStorage.\(key).flush",
            qos: .userInitiated
        )
        if let flushInterval {
            flushPublisher
                .throttle(for: .seconds(flushInterval), scheduler: flushQueue, latest: true)
                .sink { [weak self] _ in
                    self?.flush()
                }
                .store(in: &cancellables)
        }
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

    public convenience init(key: String, defaultValue: T, flushInterval: Int? = 1) {
        self.init(key: key, defaultValueClosure: { defaultValue }, flushInterval: flushInterval)
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

    public func flush() {
        memoryQueue.sync {
            if flushPending {
                WLStorage<T>.writeToDisk(fileURL: fileURL, value: memoryValue)
                flushPending = false
            }
        }
    }

    deinit {
        flush()
    }
}
