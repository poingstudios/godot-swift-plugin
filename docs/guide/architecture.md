# Architecture & Lifecycle

Learn how Godot Swift Plugin bridges the Godot Engine and Swift at the ABI level.

## Pure C GDExtension Entry Point

Godot Swift Plugin provides the standard GDExtension entry symbol:

```swift
@_cdecl("godot_swift_extension_init")
public func godot_swift_extension_init(...)
```

When Godot initializes the GDExtension library:
1. It passes `p_get_proc_address`, which loads Godot's function table.
2. At `GDEXTENSION_INITIALIZATION_SCENE`, `GodotPluginRegistry` auto-discovers all subclasses of `GodotPlugin` loaded into memory using the Objective-C runtime (`objc_getClassList`).
3. For each plugin, `GodotClassDB` creates a native Godot Object instance and registers it as an Engine singleton: `Engine.get_singleton(pluginName)`.

## Zero-Boilerplate Reflection Dispatcher

You never need to write manual binding code:

```
GDScript Call (e.g. plugin.request_tracking_authorization())
       ↓
Godot GDExtension C Interface (call_func)
       ↓
GodotVariant to Swift Arguments Conversion
       ↓
GodotPluginRegistry (Automatic camelCase / snake_case Aliasing)
       ↓
GodotRuntimeDispatcher (Objective-C Dynamic NSInvocation)
       ↓
Swift Method (@objc)
```

## Lifecycle Hooks

Your plugin can hook into engine startup and shutdown:

```swift
public final class MyPlugin: GodotPlugin {
    public override class var pluginName: String { "MyPlugin" }

    public override func onInit() {
        // Called when the plugin is registered in Godot Engine
    }

    public override func onDeinit() {
        // Called when the engine is shutting down or plugin is released
    }
}
```
