# Godot Swift Plugin — AGENTS.md

AI assistant context for the godot-swift-plugin repository. Read this before making changes.

---

## Project Overview

**Godot Swift Plugin** is an official-grade, lightweight toolkit for developing native Godot iOS/Apple plugins using pure Swift. It acts as the iOS counterpart to Android's `GodotPlugin` architecture, enabling developers to write native Apple plugins with zero engine bloat and fast compile times via Swift Package Manager (SPM).

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
├── scripts/
│   ├── test_local.sh           # Test script
│   └── sync_headers.sh         # Header sync script from godot-cpp
└── README.md
```

---

## Coding Rules & Guidelines

1. **Pure Swift:** Keep the core package free of external dependencies or Godot C++ headers so it compiles via standard `swift build` and `swift test` anywhere.
2. **License Header:** Every source file (`.swift`, `.sh`) must begin with the standard Poing Studios MIT License header block.
3. **Language Conventions & Automatic Aliasing:** Swift code must adhere to Apple's official API Design Guidelines (`camelCase`). Godot calls use standard GDScript conventions (`snake_case`). The framework registry automatically maps between `camelCase` and `snake_case` so neither language's conventions are compromised.
4. **Git Workflow:** Never commit directly unless explicitly instructed. All changes and responses must be in English.
