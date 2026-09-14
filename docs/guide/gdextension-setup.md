# GDExtension Setup

To distribute your Swift plugin with Godot, you package the compiled framework into an addon with a `.gdextension` manifest.

## Standard Addon Structure

```
res://addons/my_plugin/
├── my_plugin.gdextension
├── my_plugin.gd             # Public GDScript singleton wrapper
├── plugin.cfg               # EditorPlugin metadata
├── plugin.gd                # EditorPlugin script
├── internal/                # Internal scripts (no class_name, preload only)
└── bin/                     # Native binaries
    ├── .gdignore
    ├── MyPlugin.xcframework # iOS build (device + simulator)
    └── libMyPlugin.dylib    # Optional macOS build for desktop editor testbed
```

## GDExtension Manifest (`my_plugin.gdextension`)

Configure your `.gdextension` file:

```ini
[configuration]
entry_symbol = "godot_swift_extension_init"
compatibility_minimum = "4.6"
include_tags = ["ios"]

[libraries]
macos.debug = "res://addons/my_plugin/bin/libMyPlugin.dylib"
macos.release = "res://addons/my_plugin/bin/libMyPlugin.dylib"
ios.debug = "res://addons/my_plugin/bin/MyPlugin.xcframework"
ios.release = "res://addons/my_plugin/bin/MyPlugin.xcframework"
ios.simulator.debug = "res://addons/my_plugin/bin/MyPlugin.xcframework"
ios.simulator.release = "res://addons/my_plugin/bin/MyPlugin.xcframework"
```

## Desktop Editor Behavior

- **Godot 4.8+**: The engine reads `include_tags` and skips loading the plugin when running the editor on desktop (macOS, Windows, Linux) without requiring desktop stub binaries.
- **Godot 4.3 – 4.7**: If desktop binaries are omitted, the engine prints a non-fatal launch notice (`No GDExtension library found for current OS and architecture`). Your GDScript fallback mock will handle execution gracefully during editor testing.
