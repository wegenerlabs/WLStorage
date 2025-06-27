import XCTest
@testable import WLStorage

private struct Animal: Codable {
    var species: String
}

private class WLStorageTestsContainer {
    @WLStorage(key: "testBool", defaultValue: true)
    var testBool: Bool

    @WLStorage(key: "testInt", defaultValue: 10)
    var testInt: Int

    @WLStorage(key: "testFloat", defaultValue: 1.1)
    var testFloat: Float

    @WLStorage(key: "testDouble", defaultValue: 1.1)
    var testDouble: Double

    @WLStorage(key: "testString", defaultValue: nil)
    var testString: String?

    @WLStorage(key: "testData", defaultValue: Data([0x61]))
    var testData: Data

    @WLStorage(key: "testArray", defaultValue: ["a"])
    var testArray: [String]

    @WLStorage(key: "testSet", defaultValue: ["a"])
    var testSet: Set<String>

    @WLStorage(key: "testDictionary", defaultValue: ["a": 1])
    var testDictionary: [String: Double]

    @WLStorage(key: "testStruct", defaultValue: Animal(species: "Lion"))
    var testStruct: Animal

    func flush() {
        _testBool.flush()
        _testInt.flush()
        _testFloat.flush()
        _testDouble.flush()
        _testString.flush()
        _testData.flush()
        _testArray.flush()
        _testSet.flush()
        _testDictionary.flush()
        _testStruct.flush()
    }

    var testStringStorage: WLStorage<String?> {
        return _testString
    }
}

class WLStorageTests: XCTestCase {
    func testBool() {
        let container = WLStorageTestsContainer()
        container.testBool = false
        container.flush()
        XCTAssertFalse(WLStorageTestsContainer().testBool)
        container.testBool.toggle()
        container.flush()
        XCTAssertTrue(WLStorageTestsContainer().testBool)
    }

    func testInt() {
        let container = WLStorageTestsContainer()
        container.testInt = 0
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testInt, 0)
        container.testInt += 2
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testInt, 2)
    }

    func testFloat() {
        let container = WLStorageTestsContainer()
        container.testFloat = 0
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testFloat, 0)
        container.testFloat += 2.1
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testFloat, 2.1)
    }

    func testDouble() {
        let container = WLStorageTestsContainer()
        container.testDouble = 0
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testDouble, 0)
        container.testDouble += 2.1
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testDouble, 2.1)
    }

    func testString() {
        let container = WLStorageTestsContainer()
        container.testString = ""
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testString, "")
        container.testString = "abc"
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testString, "abc")
    }

    func testData() {
        let container = WLStorageTestsContainer()
        container.testData = Data()
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testData, Data())
        container.testData.append(contentsOf: [0x62])
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testData, Data([0x62]))
    }

    func testArray() {
        let container = WLStorageTestsContainer()
        container.testArray = []
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testArray, [])
        container.testArray.append("b")
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testArray, ["b"])
        container.testArray.insert("a", at: 0)
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testArray, ["a", "b"])
    }

    func testSet() {
        let container = WLStorageTestsContainer()
        container.testSet = []
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testSet, [])
        container.testSet.insert("b")
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testSet, ["b"])
        container.testSet.insert("a")
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testSet, ["a", "b"])
    }

    func testDictionary() {
        let container = WLStorageTestsContainer()
        container.testDictionary = [:]
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testDictionary, [:])
        container.testDictionary["b"] = 2
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testDictionary, ["b": 2])
        container.testDictionary["a"] = 1
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testDictionary, ["a": 1, "b": 2])
    }

    func testStruct() {
        let container = WLStorageTestsContainer()
        container.testStruct.species = "Cat"
        XCTAssertEqual(container.testStruct.species, "Cat")
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testStruct.species, "Cat")
        container.testStruct.species = "Dog"
        XCTAssertEqual(container.testStruct.species, "Dog")
        container.flush()
        XCTAssertEqual(WLStorageTestsContainer().testStruct.species, "Dog")
    }

    func testThrottle() {
        let container = WLStorageTestsContainer()
        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        container.testString = uuid1 // saved almost immediately
        container.testString = uuid2 // throttled
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(WLStorageTestsContainer().testString, uuid2)
    }

    @MainActor
    func testObservable() {
        let container = WLStorageTestsContainer()
        let expectation = expectation(description: "objectWillChange should emit")
        let cancellable  = container.testStringStorage.objectWillChange.sink {
            expectation.fulfill()
        }
        container.testString = UUID().uuidString
        waitForExpectations(timeout: 1)
        withExtendedLifetime(cancellable) {}
    }
}
