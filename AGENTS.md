# Godot Swift Plugin — AGENTS.md

AI assistant context for the godot-swift-plugin repository. Read this before making changes.

---

## Project Overview

**Godot Swift Plugin** is a lightweight toolkit for developing native Godot iOS/Apple plugins using pure Swift. It acts as the iOS counterpart to Android's `GodotPlugin` architecture, enabling developers to write native Apple plugins with zero engine bloat and fast compile times via Swift Package Manager (SPM).

- **Supported Platforms:** iOS 14.0+, macOS 11.0+
- **Primary Language:** Swift 5.9+ / Swift 6.0
- **Packaging:** Swift Package Manager (SPM)
- **Engine Support:** Godot 4.6+ (iOS GDExtension & arm64 Simulator baseline)

---

## Architecture & Directory Layout

```
godot-swift-plugin/
├── Package.swift               # Root SPM package manifest
├── Sources/
│   ├── CGDExtensionInterface/  # Pure C module exposing gdextension_interface.h
│   └── GodotSwiftPlugin/       # Core framework source
│       ├── GodotPlugin.swift   # Protocol & lifecycle
│       ├── GodotPluginRegistry.swift # Method & signal registration/dispatch + case aliasing
│       ├── GodotClassDB.swift  # Dynamic GDExtension ClassDB registration
│       ├── GodotInterface.swift# Runtime GDExtension C interface loader
│       ├── GodotRuntimeDispatcher.swift # Zero-boilerplate reflection dispatcher (@objcMembers)
│       ├── GodotVariant.swift  # Type conversions & JSON serialization
│       ├── GodotString.swift   # Godot String GDExtension wrapper
│       ├── GodotStringName.swift # Cached Godot StringName wrapper
│       ├── GodotOS.swift       # OS focus hooks
│       └── GodotSwiftBridge.swift # GDExtension entry point (@_cdecl)
├── Tests/
│   └── GodotSwiftPluginTests/  # Framework unit tests
├── templates/
│       ├── libstub_macos.dylib # Universal arm64 + x86_64
│       ├── stub_windows.dll    # Windows x86_64
│       ├── libstub_linux.so    # Linux x86_64
│       ├── libstub_android.so  # Android arm64
│       └── stub_ios.xcframework # Static arm64 + universal simulator
├── scripts/
│   ├── build_plugin.sh         # Universal plugin builder (macOS dylib & iOS XCFramework)
│   ├── create_plugin.sh        # Plugin project generator (creates new plugin template)
│   ├── generate_stubs.sh       # Multi-platform GDExtension stub compiler
│   ├── test_local.sh           # Test script
│   └── sync_headers.sh         # Header sync script from godot-cpp
└── README.md
```

---

## Build & Creation Commands

### Create a New Plugin
Interactive wizard:
```bash
./scripts/create_plugin.sh
```
Non-interactive CLI:
```bash
./scripts/create_plugin.sh --name MyPlugin --output-dir /path/to/MyPlugin
```

### Build Example Plugin
Via root script:
```bash
./scripts/build_local.sh all
```
Or via native SPM Command Plugin:
```bash
cd example/ios && swift package --disable-sandbox --allow-writing-to-package-directory godot-build all
```

### Run Example in Godot
```bash
./scripts/run_example.sh
```

### Build Any Plugin (Universal Builder)
```bash
./scripts/build_plugin.sh --package-dir <path_to_package> --target all
```

### Run Unit Tests
```bash
swift test
swift test --package-path example/ios
```

---

## Coding Rules & Guidelines

1. **Pure Swift:** Keep the core package free of external dependencies or Godot C++ headers so it compiles via standard `swift build` and `swift test` anywhere.
2. **License Header:** Every source file (`.swift`, `.sh`) must begin with the standard Poing Studios MIT License header block.
3. **Language Conventions & Automatic Aliasing:** Swift code must adhere to Apple's official API Design Guidelines (`camelCase`). Godot calls use standard GDScript conventions (`snake_case`). The framework registry automatically maps between `camelCase` and `snake_case` so neither language's conventions are compromised.
4. **Git Workflow:** Never commit directly unless explicitly instructed. All changes and responses must be in English.
