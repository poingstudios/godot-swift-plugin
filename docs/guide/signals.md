# Signals & Events

Signals let your native plugin notify Godot GDScript about asynchronous events (such as ad loaded, authentication completed, or in-app purchase finished).

Godot Swift Plugin provides two styles: **Property Wrapper style (`@Signal`)** and **Android-parity style (`emitSignal`)**.

---

## 1. Property Wrapper Style (`@Signal`)

The `@Signal` property wrapper provides dot-syntax and autocompletion in Xcode without hardcoding signal names at the emission site.

### Declaration

```swift
public final class MyPlugin: GodotPlugin {
    // Untyped signal (accepts any arguments or no arguments)
    @Signal
    public var sessionEnded

    // Strongly-typed signal (forces Int at Swift compile-time)
    @TypedSignal<Int>
    public var statusChanged
}
```

### Emission

```swift
// Parameterless:
sessionEnded.emit()

// With a single argument:
statusChanged.emit(3)

// With multiple arguments:
sessionEnded.emit("score", 100)

// With a Dictionary payload:
sessionEnded.emit(["uid": 42, "status": "success"])
```

The property name in camelCase (`sessionEnded`) is automatically registered in Godot Engine as snake_case (`session_ended`).

---

## 2. Android-Parity Style (`getPluginSignals` & `emitSignal`)

If you want your Swift codebase to look identical to Godot's Android `GodotPlugin` (Kotlin/Java), you can declare signals via `getPluginSignals()` and emit them using string names.

### Declaration

```swift
public final class MyPlugin: GodotPlugin {
    public override func getPluginSignals() -> [SignalInfo] {
        [
            SignalInfo("on_rewarded_ad_loaded", Int.self),
            SignalInfo("on_rewarded_ad_failed_to_load", Int.self, [String: Any].self),
            SignalInfo("session_ended")
        ]
    }
}
```

### Emission

```swift
// Direct variadic arguments (exactly like Android):
emitSignal("on_rewarded_ad_loaded", uid)
emitSignal("on_rewarded_ad_failed_to_load", uid, errorDict)
emitSignal("session_ended")
```

---

## Listening to Signals in GDScript

In your GDScript wrapper:

```gdscript
var plugin := Engine.get_singleton("MyPlugin")

plugin.connect("session_ended", _on_session_ended)
plugin.connect("on_rewarded_ad_loaded", _on_rewarded_ad_loaded)

func _on_session_ended() -> void:
    print("Session finished!")

func _on_rewarded_ad_loaded(uid: int) -> void:
    print("Ad loaded for UID:", uid)
```
