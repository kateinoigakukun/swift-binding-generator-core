# swift-binding-generator-core

Shared, reusable, target-language agnostic core libraries useful for building Swift language interop binding generators, such as [swift-java](https://github.com/swiftlang/swift-java) and [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) and more.

One example how these libraries are used is the `jextract` tool from [swift-java](https://github.com/swiftlang/swift-java). The `SwiftExtract` library offered by this package is used to analyze Swift input sources, and the swift-java library acts on the results of this analysis. The javascript interoperability tools work the same way, and you could build tools targeting other languages natively as well.

## Products

- `SwiftExtract`: analyzes Swift source files and extracts the declarations (types, functions, global variables) that should be exposed to another language, along with a symbol table and type lookup facilities. Built on [swift-syntax](https://github.com/swiftlang/swift-syntax).
- `SwiftExtractConfigurationShared`: small shared configuration enums (`AccessLevelMode`, `LogLevel`) used by binding generator plugins and tools.

## Source Compatibility

This package does not offer strict source stable API, however we make effort to either not break, or update consumers of the library when changes are made here.
This is verified with CI checking downstream consumers: swift-java, JavaScriptKit etc. This approach is beneficial to quick iteration and supporting a limited
set of official language interop libraries and tools, without locking down the API.

If you are maintaining another language target, please reach out and we'll work out a way to collaborate.

In the future we may consider a stricter source compatibility guarantee.

## Dependency

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/swiftlang/swift-binding-generator-core", from: "0.1.0"),
```

and depend on the product you need:

```swift
.product(name: "SwiftExtract", package: "swift-binding-generator-core"),
```

### Local development override

Downstream packages (such as swift-java) support overriding this dependency with a local checkout by setting the `SWIFT_BINDING_GENERATOR_CORE_PATH` environment variable to a local path:

```bash
SWIFT_BINDING_GENERATOR_CORE_PATH=~/code/swift-binding-generator-core swift build
```

