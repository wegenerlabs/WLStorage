#if !targetEnvironment(macCatalyst) && canImport(AppKit)
    import AppKit
#endif
import Combine
import Foundation
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
