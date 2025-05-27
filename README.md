# WLStorage

`WLStorage` is a thread-safe, Codable-backed property wrapper for persistent local key-value storage in Swift. It provides seamless caching of Codable types in memory with automatic, throttled persistence to disk, ensuring data is saved across app launches.

## Installation

Add `WLStorage` to your project via Swift Package Manager by specifying the package repository URL:
```
https://github.com/wegenerlabs/WLStorage.git
```

## Usage

Declare a property with the `@WLStorage` wrapper providing a unique key and a default value:

```swift
@WLStorage(key: "first_name", defaultValue: nil)
var firstName: String?
```

- On first access, `WLStorage` attempts to load the value from disk.
- If no value exists, the default is saved and used.
- Updates to the property are cached and asynchronously saved to disk, throttled to once per second.
- Data is flushed automatically on `deinit` and on app termination or backgrounding.
- The stored files are saved in the app's Documents directory under `.wlstorage` (or `.wlstorage_debug` in debug builds).
- The in-memory value is read, written and flushed in a private serial queue to ensure thread safety.

### Error handling

Throws a `fatalError` if the storage directory cannot be created.
Throws an `assertionFailure` if read/decode fails and uses default value.
Throws an `assertionFailure` if encode/write fails and retries.

## API

### Initialization

```swift
init(key: String, defaultValue: T)
```

or

```swift
init(key: String, defaultValueClosure: () -> T)
```

### Properties

- `wrappedValue: T` — The cached value.

### Methods

- `flush()` — Forces a synchronous write of the cached value to disk.

## License

MIT License
