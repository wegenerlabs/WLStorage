# WLStorage

`WLStorage` is a thread-safe, Codable-backed property wrapper for persistent local key-value storage in Swift. It keeps Codable values cached in memory and persists changes through a configurable storage backer.

## Installation

Add `WLStorage` to your project via Swift Package Manager by specifying the package repository URL:
```
https://github.com/wegenerlabs/WLStorage.git
```

## Usage

Declare a property with the `@WLStorage` wrapper by providing a unique key and a default value:

```swift
@WLStorage(key: "first_name", defaultValue: nil)
var firstName: String?
```

WLStorage is observable and compatible with SwiftUI:

```swift
private struct MyView: View {
    @EnvironmentObject var storage: WLStorage<String>

    var body: some View {
        TextField("Label", text: $storage.wrappedValue)
    }
}
```

- During initialization, `WLStorage` attempts to load the value from its backer.
- If no value exists, the default is saved and used.
- Updates to the property are cached immediately and persisted asynchronously by default.
- Persistence is throttled to once per second by default. Pass `flushInterval: nil` to disable throttled automatic flushing and call `flush()` manually.
- Data is flushed automatically on `deinit` and on app termination or backgrounding.
- The default backer stores files in the app's Documents directory under `.wlstorage` (or `.wlstorage_debug` in debug builds).
- The default backer writes atomically and stores unsafe file names as SHA-256 hashes.
- Memory access is serialized on a private queue, and disk writes are serialized on a separate private queue.
- SwiftUI change notifications are delivered on the main thread.

### Custom Backers

Use `WLStorageBacker` to provide custom persistence:

```swift
let storage = WLStorage(
    defaultValueClosure: { UserSettings() },
    backer: MyStorageBacker(key: "settings")
)
```

`WLStorageDefaultBacker` can also be initialized with a custom directory:

```swift
let backer = WLStorageDefaultBacker<UserSettings>(
    key: "settings",
    directory: cacheDirectory
)
```

Backer writes for a single `WLStorage` instance are serialized by `WLStorage` on a private background queue. Avoid sharing one backer instance across multiple `WLStorage` instances unless the backer handles its own synchronization.

### Default Disk and Serialization Error Handling

- Calls `assertionFailure` if the default storage directory URL is unavailable.
- Calls `assertionFailure` if JSON decoding or encoding fails.
- Calls `assertionFailure` if disk I/O fails.
- Missing or empty files use the default value.

## API

### Initialization

```swift
init(key: String, defaultValue: T)
```

or

```swift
init(key: String, defaultValueClosure: () -> T)
```

or

```swift
init(defaultValueClosure: () -> T, flushInterval: Int? = 1, backer: any WLStorageBacker<T>)
```

### Properties

- `key: String` — The storage key.
- `wrappedValue: T` — The cached value.

### Methods

- `flush()` — Forces a synchronous write of the latest pending value.

## Code style

Code should be formatted with `swiftformat` (default settings):
```bash
brew install swiftformat
swiftformat .
```

## License

MIT License
