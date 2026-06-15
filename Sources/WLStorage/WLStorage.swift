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
    private let backer: any WLStorageBacker<T>
    private let memoryQueue: DispatchQueue
    private var memoryValue: T
    private var flushPending = false
    private let flushPublisher = PassthroughSubject<Void, Never>()
    private let diskQueue: DispatchQueue
    private let changePublisher = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    public let objectWillChange = ObservableObjectPublisher()

    public init(defaultValueClosure: () -> T, flushInterval: Int? = 1, backer: any WLStorageBacker<T>) {
        self.backer = backer
        memoryQueue = DispatchQueue(
            label: "com.wegenerlabs.WLStorage.\(backer.key).memory",
            qos: .userInitiated
        )
        memoryValue = backer.read(defaultValueClosure: defaultValueClosure)
        let flushQueue = DispatchQueue(
            label: "com.wegenerlabs.WLStorage.\(backer.key).flush",
            qos: .userInitiated
        )
        diskQueue = DispatchQueue(
            label: "com.wegenerlabs.WLStorage.\(backer.key).disk",
            qos: .userInitiated
        )
        if let flushInterval {
            flushPublisher
                .receive(on: flushQueue)
                .throttle(for: .seconds(flushInterval), scheduler: flushQueue, latest: true)
                .sink { [weak self] _ in
                    self?.flush()
                }
                .store(in: &cancellables)
        }
        changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [objectWillChange] _ in
                objectWillChange.send()
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

    public var key: String {
        return backer.key
    }

    public var wrappedValue: T {
        get {
            memoryQueue.sync {
                memoryValue
            }
        } set {
            if Thread.isMainThread {
                objectWillChange.send()
            } else {
                changePublisher.send(())
            }
            memoryQueue.sync {
                memoryValue = newValue
                flushPending = true
            }
            flushPublisher.send(())
        }
    }

    public func flush() {
        diskQueue.sync {
            let snapshot: T? = memoryQueue.sync {
                guard flushPending else {
                    return nil
                }
                flushPending = false
                return memoryValue
            }
            guard let snapshot else {
                return
            }
            backer.write(value: snapshot)
        }
    }

    deinit {
        flush()
    }
}

public extension WLStorage {
    convenience init(key: String, defaultValue: T, flushInterval: Int? = 1) {
        let backer = WLStorageDefaultBacker<T>(key: key)
        self.init(defaultValueClosure: { defaultValue }, flushInterval: flushInterval, backer: backer)
    }

    convenience init(key: String, defaultValueClosure: () -> T, flushInterval: Int? = 1) {
        let backer = WLStorageDefaultBacker<T>(key: key)
        self.init(defaultValueClosure: defaultValueClosure, flushInterval: flushInterval, backer: backer)
    }
}
