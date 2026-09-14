# Exposing Methods (@objc)

Methods in your plugin are exposed to Godot by tagging them with `@objc` or marking the entire class with `@objcMembers`.

## Automatic Case Aliasing

Swift conventions prefer `camelCase` (e.g. `requestTrackingAuthorization()`), while GDScript conventions prefer `snake_case` (e.g. `request_tracking_authorization()`).

The framework automatically registers both aliases:

```swift
@objc public func requestTrackingAuthorization() -> Int {
    return 1
}
```

In GDScript, both calls succeed:

```gdscript
plugin.request_tracking_authorization() # ✅ Works
plugin.requestTrackingAuthorization()   # ✅ Works
```

## Supported Parameter & Return Types

All fundamental types are automatically bridged to and from Godot Variants:

| Swift Type | Godot Variant Type | Example |
| :--- | :--- | :--- |
| `String` | `TYPE_STRING` | `"hello"` |
| `Int`, `Int64`, `Int32` | `TYPE_INT` | `42` |
| `Double`, `Float` | `TYPE_FLOAT` | `3.14159` |
| `Bool` | `TYPE_BOOL` | `true` |
| `[String: Any]` | `TYPE_DICTIONARY` | `["name": "Player", "level": 1]` |
| `[Any]` | `TYPE_ARRAY` | `[1, "two", true]` |

### Dictionary Example

Returning native dictionaries from Swift directly to GDScript:

```swift
@objc public func getUserProfile() -> [String: Any] {
    return [
        "username": "GodotDev",
        "level": 10,
        "is_active": true
    ]
}
```

In GDScript:

```gdscript
var profile: Dictionary = plugin.get_user_profile()
print(profile.username) # "GodotDev"
print(profile.level)    # 10
```
