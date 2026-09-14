# Godot Swift Plugin

Lightweight, official-grade toolkit for developing native Godot iOS/Apple plugins using pure Swift.

## Overview

`godot-swift-plugin` is the iOS counterpart to Android's `GodotPlugin` architecture. It enables developers to write native Apple plugins (StoreKit, AdMob, Game Center, Apple Sign-In) in pure Swift with zero engine bloat and fast compile times.

## Features

- **Pure Swift**: Write modern Swift code with standard closures, delegates, and `async/await`.
- **Fast Builds**: Compiles in ~2 seconds (no monolithic engine wrappers).
- **Pure GDExtension ABI**: Direct `@_cdecl` interop with Godot's C interface without C++ bridge wrappers.
- **SPM First**: Distributed as a standard Swift Package via Swift Package Manager.
- **Engine Support**: Godot 4.6+ (requires Godot 4.6+ for modern Apple embedded GDExtension architecture and native arm64 iOS simulator support).

## GDExtension Configuration & Desktop Behavior

When distributing iOS-only plugins, configure `include_tags = ["ios"]` in your `.gdextension` file:

```ini
[configuration]
entry_symbol = "your_entry_symbol"
compatibility_minimum = "4.6"
include_tags = ["ios"]

[libraries]
ios.debug = "res://addons/my_plugin/ios/bin/MyPlugin.xcframework"
ios.release = "res://addons/my_plugin/ios/bin/MyPlugin.xcframework"
```

- **Godot 4.8+**: The engine reads `include_tags` ([godotengine/godot#121575](https://github.com/godotengine/godot/pull/121575)) and silently skips loading the plugin when running the editor on desktop dev machines (macOS, Windows, Linux) without requiring desktop stub binaries.
- **Godot 4.3 – 4.7**: The engine does not evaluate `include_tags` and prints an insuppressible notice on launch (`No GDExtension library found for current OS and architecture`, see [godotengine/godot#105615](https://github.com/godotengine/godot/issues/105615)). This is non-fatal: game code continues to run via GDScript fallback mocks, and iOS exports function normally.

## License

MIT License. Copyright (c) 2026-present Poing Studios.
