# Android vs. iOS Parity Guide

Godot Swift Plugin is intentionally designed so developers working on multi-platform Godot plugins (such as AdMob, ATT, Firebase, In-App Purchases) can maintain a 1:1 mental model between Android (Kotlin) and iOS (Swift).

---

## Direct Code Comparison

Using the testbed sample plugin (`Example`):

### Android (`GodotExamplePlugin.kt`)

```kotlin
import android.app.Activity
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class GodotExamplePlugin(godot: Godot?) : GodotPlugin(godot) {
    override fun getPluginName(): String {
        return "Example"
    }

    override fun getPluginSignals(): MutableSet<SignalInfo> {
        return mutableSetOf(
            SignalInfo("session_ended"),
            SignalInfo("score_calculated", Integer::class.java, String::class.java),
            SignalInfo("user_profile_updated", Dictionary::class.java)
        )
    }

    @UsedByGodot
    fun ping(message: String): String {
        return "Hello, $message! Welcome to Godot."
    }

    @UsedByGodot
    fun add_numbers(a: Int, b: Int): Int {
        val result = a + b
        emitSignal("score_calculated", result, "add")
        return result
    }

    @UsedByGodot
    fun get_user_profile(): Dictionary {
        val profile = Dictionary()
        profile["name"] = "GodotDev"
        profile["level"] = 1
        return profile
    }
}
```

### iOS Swift (`GodotExamplePlugin.swift`)

```swift
import Foundation
import GodotSwiftPlugin

public final class GodotExamplePlugin: GodotPlugin {
    public override class var pluginName: String { "Example" }

    public override func getPluginSignals() -> [SignalInfo] {
        [
            SignalInfo("session_ended"),
            SignalInfo("score_calculated", Int.self, String.self),
            SignalInfo("user_profile_updated", [String: Any].self)
        ]
    }

    @objc public func ping(message: String) -> String {
        return "Hello, \(message)! Welcome to Godot."
    }

    @objc public func add_numbers(a: Int, b: Int) -> Int {
        let result = a + b
        emitSignal("score_calculated", result, "add")
        return result
    }

    @objc public func get_user_profile() -> [String: Any] {
        return [
            "name": "GodotDev",
            "level": 1
        ]
    }
}
```

---

## Architectural Equivalents

| Concept | Android (Kotlin) | iOS (Swift) |
| :--- | :--- | :--- |
| **Plugin Base** | `GodotPlugin(godot)` | `GodotPlugin` |
| **Plugin Name** | `getPluginName(): String` | `pluginName: String` or `getPluginName()` |
| **Declare Signals** | `getPluginSignals(): MutableSet<SignalInfo>` | `getPluginSignals() -> [SignalInfo]` or `@Signal` |
| **Expose Method** | `@UsedByGodot` | `@objc` or `@objcMembers` |
| **Emit Signal** | `emitSignal(name, ...args)` | `emitSignal(name, ...args)` |
| **Dictionary Type** | `org.godotengine.godot.Dictionary` | `[String: Any]` |
| **Array Type** | `Array<Any>` | `[Any]` |
| **Packaging** | Android AAR (`build.gradle`) | Swift Package (`Package.swift`) |
