// swiftformat:disable noForceUnwrapInTests

import WLStorage
import XCTest

private struct Animal: Codable {
    var species: String
}

final class TestBacker<T: Codable & Sendable>: WLStorageBacker {
    let key: String

    private let lock = NSLock()
    private var storedValue: T?
    private var _readCount = 0
    private var _writeValues: [T] = []
    var onWrite: ((T) -> Void)?

    init(key: String, storedValue: T? = nil) {
        self.key = key
        self.storedValue = storedValue
    }

    var readCount: Int {
        lock.withLock {
            _readCount
        }
    }

    var writeValues: [T] {
        lock.withLock {
            _writeValues
        }
    }

    func read(defaultValueClosure: () -> T) -> T {
        lock.withLock {
            _readCount += 1
            return storedValue ?? defaultValueClosure()
        }
    }

    func write(value: T) {
        lock.withLock {
            storedValue = value
            _writeValues.append(value)
        }
        onWrite?(value)
    }
}

final class SlowTestBacker<T: Codable & Sendable>: WLStorageBacker {
    let key: String

    private let lock = NSLock()
    private let writeDelay: TimeInterval
    private var storedValue: T?
    private var _writeValues: [T] = []
    var onWriteStart: ((T) -> Void)?
    var onWrite: ((T) -> Void)?

    init(key: String, storedValue: T? = nil, writeDelay: TimeInterval) {
        self.key = key
        self.storedValue = storedValue
        self.writeDelay = writeDelay
    }

    var writeValues: [T] {
        lock.withLock {
            _writeValues
        }
    }

    func read(defaultValueClosure: () -> T) -> T {
        lock.withLock {
            storedValue ?? defaultValueClosure()
        }
    }

    func write(value: T) {
        onWriteStart?(value)
        Thread.sleep(forTimeInterval: writeDelay)
        lock.withLock {
            storedValue = value
            _writeValues.append(value)
        }
        onWrite?(value)
    }
}

final class BlockingFirstWriteBacker<T: Codable & Sendable>: WLStorageBacker {
    let key: String

    private let lock = NSLock()
    private let firstWriteStarted = DispatchSemaphore(value: 0)
    private let unblockFirstWrite = DispatchSemaphore(value: 0)
    private var shouldBlockFirstWrite = true
    private var storedValue: T?
    private var _writeValues: [T] = []

    init(key: String, storedValue: T? = nil) {
        self.key = key
        self.storedValue = storedValue
    }

    var writeValues: [T] {
        lock.withLock {
            _writeValues
        }
    }

    func read(defaultValueClosure: () -> T) -> T {
        lock.withLock {
            storedValue ?? defaultValueClosure()
        }
    }

    func write(value: T) {
        let shouldBlock = lock.withLock {
            if shouldBlockFirstWrite {
                shouldBlockFirstWrite = false
                return true
            }
            return false
        }
        if shouldBlock {
            firstWriteStarted.signal()
            unblockFirstWrite.wait()
        }
        lock.withLock {
            storedValue = value
            _writeValues.append(value)
        }
    }

    func waitForFirstWriteStarted(timeout: DispatchTime) -> DispatchTimeoutResult {
        return firstWriteStarted.wait(timeout: timeout)
    }

    func releaseFirstWrite() {
        unblockFirstWrite.signal()
    }
}

final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

private class WLStorageTestsContainer {
    private let _testBool: WLStorage<Bool>
    private let _testInt: WLStorage<Int>
    private let _testFloat: WLStorage<Float>
    private let _testDouble: WLStorage<Double>
    private let _testString: WLStorage<String?>
    private let _testStringSlow: WLStorage<String?>
    private let _testData: WLStorage<Data>
    private let _testArray: WLStorage<[String]>
    private let _testSet: WLStorage<Set<String>>
    private let _testDictionary: WLStorage<[String: Double]>
    private let _testStruct: WLStorage<Animal>

    init(directory: URL) {
        _testBool = Self.storage(key: "testBool", defaultValue: true, directory: directory)
        _testInt = Self.storage(key: "testInt", defaultValue: 10, directory: directory)
        _testFloat = Self.storage(key: "testFloat", defaultValue: 1.1, directory: directory)
        _testDouble = Self.storage(key: "testDouble", defaultValue: 1.1, directory: directory)
        _testString = Self.storage(key: "testString", defaultValue: nil, directory: directory)
        _testStringSlow = Self.storage(key: "testStringSlow", defaultValue: nil, flushInterval: 3, directory: directory)
        _testData = Self.storage(key: "testData", defaultValue: Data([0x61]), directory: directory)
        _testArray = Self.storage(key: "testArray", defaultValue: ["a"], directory: directory)
        _testSet = Self.storage(key: "testSet", defaultValue: ["a"], directory: directory)
        _testDictionary = Self.storage(key: "testDictionary", defaultValue: ["a": 1], directory: directory)
        _testStruct = Self.storage(key: "testStruct", defaultValue: Animal(species: "Lion"), directory: directory)
    }

    var testBool: Bool {
        get { _testBool.wrappedValue }
        set { _testBool.wrappedValue = newValue }
    }

    var testInt: Int {
        get { _testInt.wrappedValue }
        set { _testInt.wrappedValue = newValue }
    }

    var testFloat: Float {
        get { _testFloat.wrappedValue }
        set { _testFloat.wrappedValue = newValue }
    }

    var testDouble: Double {
        get { _testDouble.wrappedValue }
        set { _testDouble.wrappedValue = newValue }
    }

    var testString: String? {
        get { _testString.wrappedValue }
        set { _testString.wrappedValue = newValue }
    }

    var testStringSlow: String? {
        get { _testStringSlow.wrappedValue }
        set { _testStringSlow.wrappedValue = newValue }
    }

    var testData: Data {
        get { _testData.wrappedValue }
        set { _testData.wrappedValue = newValue }
    }

    var testArray: [String] {
        get { _testArray.wrappedValue }
        set { _testArray.wrappedValue = newValue }
    }

    var testSet: Set<String> {
        get { _testSet.wrappedValue }
        set { _testSet.wrappedValue = newValue }
    }

    var testDictionary: [String: Double] {
        get { _testDictionary.wrappedValue }
        set { _testDictionary.wrappedValue = newValue }
    }

    var testStruct: Animal {
        get { _testStruct.wrappedValue }
        set { _testStruct.wrappedValue = newValue }
    }

    func flush() {
        _testBool.flush()
        _testInt.flush()
        _testFloat.flush()
        _testDouble.flush()
        _testString.flush()
        _testStringSlow.flush()
        _testData.flush()
        _testArray.flush()
        _testSet.flush()
        _testDictionary.flush()
        _testStruct.flush()
    }

    var testStringStorage: WLStorage<String?> {
        return _testString
    }

    var testStringSlowStorage: WLStorage<String?> {
        return _testStringSlow
    }

    private static func storage<T: Codable & Sendable>(
        key: String,
        defaultValue: T,
        flushInterval: Int? = 1,
        directory: URL
    ) -> WLStorage<T> {
        return WLStorage(
            defaultValueClosure: { defaultValue },
            flushInterval: flushInterval,
            backer: WLStorageDefaultBacker<T>(key: key, directory: directory)
        )
    }
}

class WLStorageTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WLStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    private func makeContainer() -> WLStorageTestsContainer {
        return WLStorageTestsContainer(directory: temporaryDirectory)
    }

    private func makeStorage<T: Codable & Sendable>(
        key: String,
        defaultValue: T,
        flushInterval: Int? = 1
    ) -> WLStorage<T> {
        return WLStorage(
            defaultValueClosure: { defaultValue },
            flushInterval: flushInterval,
            backer: WLStorageDefaultBacker<T>(key: key, directory: temporaryDirectory)
        )
    }

    func testBool() {
        let container = makeContainer()
        container.testBool = false
        container.flush()
        XCTAssertFalse(makeContainer().testBool)
        container.testBool.toggle()
        container.flush()
        XCTAssertTrue(makeContainer().testBool)
    }

    func testInt() {
        let container = makeContainer()
        container.testInt = 0
        container.flush()
        XCTAssertEqual(makeContainer().testInt, 0)
        container.testInt += 2
        container.flush()
        XCTAssertEqual(makeContainer().testInt, 2)
    }

    func testFloat() {
        let container = makeContainer()
        container.testFloat = 0
        container.flush()
        XCTAssertEqual(makeContainer().testFloat, 0)
        container.testFloat += 2.1
        container.flush()
        XCTAssertEqual(makeContainer().testFloat, 2.1)
    }

    func testDouble() {
        let container = makeContainer()
        container.testDouble = 0
        container.flush()
        XCTAssertEqual(makeContainer().testDouble, 0)
        container.testDouble += 2.1
        container.flush()
        XCTAssertEqual(makeContainer().testDouble, 2.1)
    }

    func testString() {
        let container = makeContainer()
        container.testString = ""
        container.flush()
        XCTAssertEqual(makeContainer().testString, "")
        container.testString = "abc"
        container.flush()
        XCTAssertEqual(makeContainer().testString, "abc")
    }

    func testData() {
        let container = makeContainer()
        container.testData = Data()
        container.flush()
        XCTAssertEqual(makeContainer().testData, Data())
        container.testData.append(contentsOf: [0x62])
        container.flush()
        XCTAssertEqual(makeContainer().testData, Data([0x62]))
    }

    func testArray() {
        let container = makeContainer()
        container.testArray = []
        container.flush()
        XCTAssertEqual(makeContainer().testArray, [])
        container.testArray.append("b")
        container.flush()
        XCTAssertEqual(makeContainer().testArray, ["b"])
        container.testArray.insert("a", at: 0)
        container.flush()
        XCTAssertEqual(makeContainer().testArray, ["a", "b"])
    }

    func testSet() {
        let container = makeContainer()
        container.testSet = []
        container.flush()
        XCTAssertEqual(makeContainer().testSet, [])
        container.testSet.insert("b")
        container.flush()
        XCTAssertEqual(makeContainer().testSet, ["b"])
        container.testSet.insert("a")
        container.flush()
        XCTAssertEqual(makeContainer().testSet, ["a", "b"])
    }

    func testDictionary() {
        let container = makeContainer()
        container.testDictionary = [:]
        container.flush()
        XCTAssertEqual(makeContainer().testDictionary, [:])
        container.testDictionary["b"] = 2
        container.flush()
        XCTAssertEqual(makeContainer().testDictionary, ["b": 2])
        container.testDictionary["a"] = 1
        container.flush()
        XCTAssertEqual(makeContainer().testDictionary, ["a": 1, "b": 2])
    }

    func testStruct() {
        let container = makeContainer()
        container.testStruct.species = "Cat"
        XCTAssertEqual(container.testStruct.species, "Cat")
        container.flush()
        XCTAssertEqual(makeContainer().testStruct.species, "Cat")
        container.testStruct.species = "Dog"
        XCTAssertEqual(container.testStruct.species, "Dog")
        container.flush()
        XCTAssertEqual(makeContainer().testStruct.species, "Dog")
    }

    func testThrottle() {
        var container: WLStorageTestsContainer? = makeContainer()
        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        let uuid3 = UUID().uuidString
        let uuid4 = UUID().uuidString

        container!.testString = uuid1 // should not be throttled
        container?.testStringSlow = uuid1 // should not be throttled
        Thread.sleep(forTimeInterval: 0.25) // slight delay, async flush
        XCTAssertEqual(makeContainer().testString, uuid1)
        XCTAssertEqual(makeContainer().testStringSlow, uuid1)

        container!.testString = uuid2 // should be throttled
        container!.testStringSlow = uuid2 // should be throttled
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(makeContainer().testString, uuid2)
        XCTAssertEqual(makeContainer().testStringSlow, uuid1) // not yet!
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(makeContainer().testStringSlow, uuid2)

        container!.testString = uuid3
        container!.testStringSlow = uuid3
        container!.testString = uuid4
        container!.testStringSlow = uuid4
        container = nil // deinit, sync flush
        XCTAssertEqual(makeContainer().testString, uuid4)
        XCTAssertEqual(makeContainer().testStringSlow, uuid4)
    }

    @MainActor
    func testObservable() {
        let container = makeContainer()
        let expectation = expectation(description: "objectWillChange should emit")
        let cancellable = container.testStringStorage.objectWillChange.sink {
            expectation.fulfill()
        }
        container.testString = UUID().uuidString
        waitForExpectations(timeout: 1)
        withExtendedLifetime(cancellable) {}
    }

    func testInjectedBackerInitializesFromBacker() {
        let backer = TestBacker(key: "injectedInitialization", storedValue: 42)
        let storage = WLStorage(
            defaultValueClosure: {
                XCTFail("Default value should not be used")
                return 1
            },
            backer: backer
        )

        XCTAssertEqual(storage.key, "injectedInitialization")
        XCTAssertEqual(storage.wrappedValue, 42)
        XCTAssertEqual(backer.readCount, 1)
        XCTAssertEqual(backer.writeValues, [])
    }

    func testInjectedBackerInitializesFromDefaultWhenBackerHasNoValue() {
        let backer = TestBacker<Int>(key: "injectedDefault")
        var defaultValueCallCount = 0
        let storage = WLStorage(
            defaultValueClosure: {
                defaultValueCallCount += 1
                return 99
            },
            backer: backer
        )

        XCTAssertEqual(storage.key, "injectedDefault")
        XCTAssertEqual(storage.wrappedValue, 99)
        XCTAssertEqual(defaultValueCallCount, 1)
        XCTAssertEqual(backer.readCount, 1)
        XCTAssertEqual(backer.writeValues, [])
    }

    func testInjectedBackerExplicitFlushWritesPendingValue() {
        let backer = TestBacker(key: "injectedExplicitFlush", storedValue: 1)
        let storage = WLStorage(
            defaultValueClosure: { 0 },
            flushInterval: nil,
            backer: backer
        )

        storage.wrappedValue = 2
        XCTAssertEqual(backer.writeValues, [])

        storage.flush()
        XCTAssertEqual(backer.writeValues, [2])
    }

    func testExplicitFlushWaitsForInFlightWriteAndWritesLatestValue() {
        let backer = BlockingFirstWriteBacker(key: "explicitFlushBlockedWrite", storedValue: 0)
        let storage = WLStorage(
            defaultValueClosure: { 0 },
            flushInterval: nil,
            backer: backer
        )
        let storageBox = UncheckedSendableBox(storage)
        let firstFlushFinished = DispatchSemaphore(value: 0)
        let secondFlushFinished = DispatchSemaphore(value: 0)

        storage.wrappedValue = 1
        DispatchQueue.global(qos: .userInitiated).async {
            storageBox.value.flush()
            firstFlushFinished.signal()
        }

        XCTAssertEqual(backer.waitForFirstWriteStarted(timeout: .now() + 2), .success)
        storage.wrappedValue = 2

        DispatchQueue.global(qos: .userInitiated).async {
            storageBox.value.flush()
            secondFlushFinished.signal()
        }

        XCTAssertEqual(secondFlushFinished.wait(timeout: .now() + 0.1), .timedOut)
        backer.releaseFirstWrite()
        XCTAssertEqual(firstFlushFinished.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(secondFlushFinished.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(backer.writeValues, [1, 2])
    }

    func testInjectedBackerThrottledFlushWritesLatestValue() {
        let backer = TestBacker(key: "injectedThrottle", storedValue: "initial")
        let latestWrite = expectation(description: "latest throttled write should reach backer")
        backer.onWrite = { value in
            if value == "third" {
                latestWrite.fulfill()
            }
        }

        let storage = WLStorage(
            defaultValueClosure: { "default" },
            flushInterval: 1,
            backer: backer
        )
        storage.wrappedValue = "first"
        storage.wrappedValue = "second"
        storage.wrappedValue = "third"

        wait(for: [latestWrite], timeout: 2)
        XCTAssertEqual(backer.writeValues.last, "third")
    }

    func testSlowBackerWriteDoesNotBlockThrottledSettersAndStoresLatestValue() {
        let backer = SlowTestBacker(key: "slowThrottle", storedValue: 0, writeDelay: 0.5)
        let slowWriteStarted = expectation(description: "slow write should start")
        slowWriteStarted.assertForOverFulfill = false
        let latestWrite = expectation(description: "latest throttled write should reach backer")
        latestWrite.assertForOverFulfill = false
        backer.onWriteStart = { _ in
            slowWriteStarted.fulfill()
        }
        backer.onWrite = { value in
            if value == 10 {
                latestWrite.fulfill()
            }
        }

        let storage = WLStorage(
            defaultValueClosure: { 0 },
            flushInterval: 1,
            backer: backer
        )

        storage.wrappedValue = -1
        wait(for: [slowWriteStarted], timeout: 2)

        for value in 1 ... 10 {
            let start = Date()
            storage.wrappedValue = value
            XCTAssertLessThan(Date().timeIntervalSince(start), 0.2)
            Thread.sleep(forTimeInterval: 0.1)
        }

        wait(for: [latestWrite], timeout: 2)
        XCTAssertEqual(backer.writeValues.last, 10)
    }

    func testInjectedBackerDeinitFlushWritesPendingValue() {
        let backer = TestBacker(key: "injectedDeinit", storedValue: 1)
        var storage: WLStorage<Int>? = WLStorage(
            defaultValueClosure: { 0 },
            flushInterval: nil,
            backer: backer
        )

        storage?.wrappedValue = 2
        XCTAssertEqual(backer.writeValues, [])

        storage = nil
        XCTAssertEqual(backer.writeValues, [2])
    }

    func testDefaultBackerUsesInjectedDirectory() throws {
        let directory = temporaryDirectory.appendingPathComponent("custom", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let backer = WLStorageDefaultBacker<Int>(key: "customDirectory", directory: directory)
        let storage = WLStorage(
            defaultValueClosure: { 0 },
            flushInterval: nil,
            backer: backer
        )

        XCTAssertEqual(backer.fileURL?.deletingLastPathComponent(), directory)
        storage.wrappedValue = 123
        storage.flush()

        let fileURL = try XCTUnwrap(backer.fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let reread = WLStorage(
            defaultValueClosure: { 0 },
            flushInterval: nil,
            backer: WLStorageDefaultBacker<Int>(key: "customDirectory", directory: directory)
        )
        XCTAssertEqual(reread.wrappedValue, 123)
    }

    func testConcurrentSettersFlushFinalValue() {
        let backer = TestBacker(key: "concurrentSetters", storedValue: 0)
        let storage = WLStorage(
            defaultValueClosure: { 0 },
            flushInterval: nil,
            backer: backer
        )
        let storageBox = UncheckedSendableBox(storage)
        let group = DispatchGroup()

        for value in 1 ... 100 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                storageBox.value.wrappedValue = value
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
        storage.wrappedValue = 999
        storage.flush()
        XCTAssertEqual(backer.writeValues, [999])
    }

    func testNormalKey() {
        let key = "abcABC.-_"
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(a!.key, fileURL.lastPathComponent)
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testLongKey() {
        let key = String(repeating: "t", count: 1024)
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(fileURL.lastPathComponent, "3ca0903dc7f20cee7c4d65f83df4968296be28eaf7f339668b1add6d60416afd")
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testMaximumLengthKey() {
        let key = String(repeating: "t", count: 127)
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(fileURL.lastPathComponent, key)
        XCTAssertEqual(a!.key, fileURL.lastPathComponent)
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testOverMaximumLengthKey() {
        let key = String(repeating: "t", count: 128)
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(fileURL.lastPathComponent, "9fc73bfdab7bf74ecb69af224adcefca194ce379842402e334a7547653a66abe")
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testShortKey() {
        let key = ""
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(fileURL.lastPathComponent, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testSlashKey() {
        let key = "/"
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(fileURL.lastPathComponent, "8a5edab282632443219e051e4ade2d1d5bbc671c781051bf1437897cbdfea0f1")
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testDotKey() {
        let key = "."
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(fileURL.lastPathComponent, "cdb4ee2aea69cc6a83331bbe96dc2caa9a299d21329efb0336fc02a82e1839a8")
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testDoubleDotKey() {
        let key = ".."
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(fileURL.lastPathComponent, "5ec1f7e700f37c3d0b2981d04855fc34b94aaa15457b05ca571817442d228f81")
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }

    func testNormalLongKey() {
        let key = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
        var a: WLStorage? = makeStorage(key: key, defaultValue: 1)
        let fileURL = WLStorageDefaultBacker<Int>(key: key, directory: temporaryDirectory).fileURL!
        XCTAssertEqual(a!.key, fileURL.lastPathComponent)
        a?.wrappedValue = 2
        a = nil
        let b = makeStorage(key: key, defaultValue: 1)
        XCTAssertEqual(b.wrappedValue, 2)
    }
}
