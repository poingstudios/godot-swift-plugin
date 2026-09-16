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
    ├── libMyPlugin.dylib    # Optional macOS build for desktop editor testbed
    └── stubs/               # Precompiled multiplatform stubs
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

# Multiplatform stubs (silences engine notices on unsupported OS & arch):
windows.debug.x86_64 = "res://addons/my_plugin/bin/stubs/stub_windows_x86_64.dll"
windows.release.x86_64 = "res://addons/my_plugin/bin/stubs/stub_windows_x86_64.dll"
windows.debug.arm64 = "res://addons/my_plugin/bin/stubs/stub_windows_arm64.dll"
windows.release.arm64 = "res://addons/my_plugin/bin/stubs/stub_windows_arm64.dll"

linux.debug.x86_64 = "res://addons/my_plugin/bin/stubs/libstub_linux_x86_64.so"
linux.release.x86_64 = "res://addons/my_plugin/bin/stubs/libstub_linux_x86_64.so"
linux.debug.arm64 = "res://addons/my_plugin/bin/stubs/libstub_linux_arm64.so"
linux.release.arm64 = "res://addons/my_plugin/bin/stubs/libstub_linux_arm64.so"

android.debug.arm64 = "res://addons/my_plugin/bin/stubs/libstub_android_arm64.so"
android.release.arm64 = "res://addons/my_plugin/bin/stubs/libstub_android_arm64.so"
android.debug.x86_64 = "res://addons/my_plugin/bin/stubs/libstub_android_x86_64.so"
android.release.x86_64 = "res://addons/my_plugin/bin/stubs/libstub_android_x86_64.so"
```

## Platform Filtering (`include_tags` & `exclude_tags`)

Starting in **Godot 4.8+**, GDExtension supports tag-based inclusion and exclusion filters under `[configuration]`:

- **`include_tags` (Whitelist)**: The extension **only** loads if the running environment matches at least one of the specified tags. If no tag matches, Godot skips the extension (`ERR_SKIP`) without inspecting `[libraries]` or printing errors.
  ```ini
  include_tags = ["ios", "macos"] # Loads on iOS and macOS; completely ignored on Windows/Linux/Android
  ```

- **`exclude_tags` (Blacklist)**: The extension is **skipped** if the environment matches any tag. Useful for excluding specific environments (such as simulator or in-editor runs).
  ```ini
  exclude_tags = ["simulator"] # Loads on physical iOS devices, but skipped on iOS Simulator
  ```

### Backward Compatibility (Godot 4.6 – 4.7)
- In Godot 4.6 and 4.7, `include_tags` and `exclude_tags` are ignored as unknown keys by the engine's config loader.
- Godot 4.6 / 4.7 falls back to reading `[libraries]`. The precompiled multiplatform stubs handle these engine versions cleanly, while `include_tags` provides native engine filtering for Godot 4.8+.

## Multiplatform Stubs

In Godot 4.6–4.7, opening a project on an OS or architecture missing a binary displays a launch notice:
`No GDExtension library found for current OS and architecture`.

Precompiled stubs in `bin/stubs/` provide ultra-lightweight no-op C entry points (< 80 KB total) for all major platforms and CPU architectures:
- **macOS**: `libstub_macos.dylib` (Universal arm64 + x86_64)
- **Windows**: `stub_windows_x86_64.dll` & `stub_windows_arm64.dll`
- **Linux**: `libstub_linux_x86_64.so` & `libstub_linux_arm64.so`
- **Android**: `libstub_android_arm64.so` & `libstub_android_x86_64.so`
- **iOS**: `stub_ios.xcframework` (Universal arm64 device + universal simulator)

Generated plugins automatically configure these stubs so team members on any operating system and CPU architecture (Intel, AMD, Apple Silicon, Qualcomm Snapdragon, ARM Linux) can work seamlessly without warnings.
