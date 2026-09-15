# Godot Swift Plugin

Lightweight, official-grade toolkit for developing native Godot iOS/Apple plugins using pure Swift.

## Overview

`godot-swift-plugin` is the iOS counterpart to Android's `GodotPlugin` architecture. It enables developers to write native Apple plugins (StoreKit, Game Center, Apple Sign-In, etc.) in pure Swift with zero engine bloat and fast compile times.

---

## Quickstart

### 1. Create a Plugin

#### Option A: 1-Line Wizard via `curl` (Recommended)
Generates the complete hybrid project (Swift package + Godot addon + stubs + sample scene):

```bash
curl -fsSL https://raw.githubusercontent.com/poingstudios/godot-swift-plugin/master/scripts/create_plugin.sh | bash
```

*(Or from a local clone: `./scripts/create_plugin.sh`)*

#### Option B: Pure Swift CLI (`swift package init`)
Initialize directly using Swift Package Manager CLI:

```bash
# 1. Create bare Swift library:
mkdir MyPlugin && cd MyPlugin
swift package init --name MyPlugin --type library

# 2. Automatically attach GodotSwiftPlugin & the godot-build command:
swift package add-dependency https://github.com/poingstudios/godot-swift-plugin --branch master
swift package add-target-dependency GodotSwiftPlugin MyPlugin --package godot-swift-plugin
```

---

### 2. Write in Pure Swift

Subclass `GodotPlugin`. Methods marked `@objc` are automatically registered in Godot, and `@Signal` exposes signals:

```swift
import Foundation
import GodotSwiftPlugin

public final class MyPlugin: GodotPlugin {
    public override class var pluginName: String { "MyPlugin" }

    @Signal
    public var scoreUpdated

    @objc public func greet(name: String) -> String {
        return "Hello, \(name)!"
    }

    @objc public func addScore(points: Int) -> Int {
        scoreUpdated.emit(points)
        return points
    }
}
```

### 3. Call from GDScript

Access your plugin via `Engine.get_singleton()`:

```gdscript
func _ready() -> void:
	if Engine.has_singleton("MyPlugin"):
		var plugin := Engine.get_singleton("MyPlugin")
		plugin.score_updated.connect(func(score): print("Score:", score))
		print(plugin.greet("Godot"))
		plugin.add_score(100)
```

### 4. Build Binaries

```bash
./scripts/build_local.sh all
```

Or directly using Swift Package Manager's native command plugin:

```bash
swift package --disable-sandbox --allow-writing-to-package-directory godot-build all
```

Target options: `all` (macOS dylib + iOS XCFramework), `macos`, or `ios`.

---

## Precompiled Stubs

All scaffolded plugins include lightweight precompiled GDExtension stubs in `addons/<plugin>/bin/stubs/` (macOS, Windows, Linux, Android, and iOS), silencing Godot's `No GDExtension library found` notice when running the editor on any desktop OS.

To recompile stubs locally:

```bash
./scripts/generate_stubs.sh
```

---

## Documentation

Comprehensive guides are available in the [documentation](docs/guide/):
- [Getting Started](docs/guide/getting-started.md)
- [Architecture & Lifecycle](docs/guide/architecture.md)
- [Methods & Type Marshalling](docs/guide/methods.md)
- [Signals & Events](docs/guide/signals.md)
- [Android Parity Guide](docs/guide/android-parity.md)

---

## License

MIT License. Copyright (c) 2026-present Poing Studios.
