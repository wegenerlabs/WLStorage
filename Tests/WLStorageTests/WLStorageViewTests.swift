import XCTest
import SwiftUI
import Combine
import ViewInspector
@testable import WLStorage

class WLStorageViewTests: XCTestCase {
    private struct MyView: View {
        @EnvironmentObject var storage: WLStorage<String>

        var body: some View {
            TextField("Label", text: $storage.wrappedValue)
        }
    }

    @WLStorage(key: "testString", defaultValue: "")
    private var storage: String

    @MainActor
    func test() throws {
        let view = MyView()
            .environmentObject(_storage)
        let textField = try view.inspect().find(ViewType.TextField.self)
        var string = UUID().uuidString
        try textField.setInput(string)
        XCTAssertEqual(storage, string)
        string = UUID().uuidString
        try textField.setInput(string)
        XCTAssertEqual(storage, string)
    }
}
