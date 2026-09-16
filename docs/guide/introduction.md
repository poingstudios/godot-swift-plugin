# Introduction

**Godot Swift Plugin** is a lightweight toolkit developed by [Poing Studios](https://github.com/Poing-Studios) for building native iOS and Apple plugins in Godot 4.x using pure Swift.

## Why Godot Swift Plugin?

Historically, creating native iOS plugins for Godot required writing complex Objective-C++ wrappers, linking against heavy `godot-cpp` submodules, or managing fragile bridge files.

In contrast, Godot has always had a clean Java/Kotlin `GodotPlugin` architecture on Android.

**Godot Swift Plugin brings the same clean experience to iOS:**

- **Zero C++ bloat**: Interacts directly with Godot's C GDExtension interface (`gdextension_interface.h`).
- **Standard SPM workflow**: Use standard `Package.swift` and Xcode tools.
- **Fast iterations**: Compiles in a couple seconds rather than minutes.
- **Reflection & Aliasing**: Automatic discovery of `@objc` methods and automatic mapping between Swift `camelCase` and GDScript `snake_case`.

## Compatibility

- **Platforms**: iOS 14.0+, macOS 11.0+ (desktop testbed)
- **Engine**: Godot 4.6+ (required for embedded GDExtension architecture and native arm64 iOS simulator support)
- **Swift**: Swift 5.9+ / Swift 6.0
