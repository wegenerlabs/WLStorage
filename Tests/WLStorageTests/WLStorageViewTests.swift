import SwiftUI
import ViewInspector
import WLStorage
import XCTest

class WLStorageViewTests: XCTestCase {
    private struct MyView: View {
        @EnvironmentObject var storage: WLStorage<String>

        var body: some View {
            TextField("Label", text: $storage.wrappedValue)
        }
    }

    @MainActor
    func test() throws {
        let storage = WLStorage(
            defaultValueClosure: { "" },
            flushInterval: nil,
            backer: TestBacker(key: "viewStorage", storedValue: "")
        )
        let view = MyView()
            .environmentObject(storage)
        let textField = try view.inspect().find(ViewType.TextField.self)
        var string = UUID().uuidString
        try textField.setInput(string)
        XCTAssertEqual(storage.wrappedValue, string)
        string = UUID().uuidString
        try textField.setInput(string)
        XCTAssertEqual(storage.wrappedValue, string)
    }
}
