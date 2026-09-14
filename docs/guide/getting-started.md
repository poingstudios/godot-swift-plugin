# Quickstart

Get up and running with your first Swift plugin in minutes.

## 1. Package Configuration

Create a standard Swift package for your iOS plugin. In your `Package.swift`, depend on `GodotSwiftPlugin`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyCustomPlugin",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "MyCustomPlugin",
            type: .static,
            targets: ["MyCustomPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Poing-Studios/godot-swift-plugin", branch: "master")
    ],
    targets: [
        .target(
            name: "MyCustomPlugin",
            dependencies: [
                .product(name: "GodotSwiftPlugin", package: "godot-swift-plugin")
            ]
        )
    ]
)
```

## 2. Implement Your Plugin

Create a subclass of `GodotPlugin`. Override `pluginName` to specify the singleton name that Godot GDScript will access:

```swift
import Foundation
import GodotSwiftPlugin

public final class MyCustomPlugin: GodotPlugin {
    public override class var pluginName: String { "MyCustom" }

    // Signals can be declared using @Signal property wrapper:
    @Signal
    public var onTaskCompleted

    // Or declared in getPluginSignals() (Android style):
    public override func getPluginSignals() -> [SignalInfo] {
        [SignalInfo("on_score_updated", Int.self)]
    }

    // Methods marked with @objc are automatically callable from GDScript:
    @objc public func ping(message: String) -> String {
        return "Pong: \(message)"
    }

    @objc public func add_numbers(a: Int, b: Int) -> Int {
        let sum = a + b
        emitSignal("on_score_updated", sum)
        return sum
    }
}
```

## 3. GDScript Consumption

In your Godot project, call your plugin singleton:

```gdscript
extends Node

func _ready() -> void:
    if Engine.has_singleton("MyCustom"):
        var plugin := Engine.get_singleton("MyCustom")
        plugin.connect("on_score_updated", _on_score_updated)
        
        var response := plugin.ping("Hello Swift!")
        print(response) # "Pong: Hello Swift!"
        
        var sum := plugin.add_numbers(10, 20)
        print(sum) # 30

func _on_score_updated(score: int) -> void:
    print("New score:", score)
```
