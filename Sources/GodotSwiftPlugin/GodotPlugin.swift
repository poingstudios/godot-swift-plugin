// MIT License
//
// Copyright (c) 2026-present Poing Studios
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

/// Represents signal metadata mirroring Android's `org.godotengine.godot.plugin.SignalInfo`.
public struct SignalInfo: ExpressibleByStringLiteral, Sendable {
    public let name: String
    public let paramTypes: [Any.Type]

    public init(_ name: String, _ paramTypes: Any.Type...) {
        self.name = name
        self.paramTypes = paramTypes
    }

    public init(_ name: String, paramTypes: [Any.Type]) {
        self.name = name
        self.paramTypes = paramTypes
    }

    public init(stringLiteral value: String) {
        self.name = value
        self.paramTypes = []
    }
}

/// Base class for all native Godot iOS/Apple plugins written in Swift.
/// Inherit from this class and mark your subclass with `@objcMembers` or `@objc` on exposed methods.
@objc(GodotPlugin)
open class GodotPlugin: NSObject {
    /// The unique singleton name registered in Godot Engine (e.g., "ATT", "AdMob").
    /// Defaults to the class name if not overridden.
    @objc open class var pluginName: String {
        return String(describing: self)
    }

    /// Mirrors Android's `getPluginName()` for exact multi-platform API parity.
    open func getPluginName() -> String {
        return Self.pluginName
    }

    /// The native GDExtension ClassDB class name.
    /// Defaults to the Swift class name, or "\(pluginName)Plugin" if equal to pluginName,
    /// avoiding collisions with GDScript class_name (such as class_name ATT).
    @objc open class var pluginClassName: String {
        let swiftName = String(describing: self)
        if swiftName == pluginName || swiftName == "GodotPlugin" {
            return "\(pluginName)Plugin"
        }
        return swiftName
    }

    /// Mirrors Android's `getPluginSignals()` for exact multi-platform API parity.
    open func getPluginSignals() -> [SignalInfo] {
        return []
    }

    /// List of signals exposed by this plugin to Godot Engine.
    open var pluginSignals: [SignalInfo] {
        return getPluginSignals()
    }

    public required override init() {
        super.init()
    }

    /// Method registration hook called upon initialization.
    /// By default, automatically discovers all `@objc` methods on this class and registers them.
    open func registerMethods(in registry: GodotPluginRegistry) {
        let name = Self.pluginName

        // 1. Auto-discover candidate @objc methods with typed metadata
        let metadataList = GodotRuntimeDispatcher.discoverMethodMetadata(for: self)
        for meta in metadataList {
            registry.registerMethod(pluginName: name, metadata: meta) { [weak self] args in
                guard let self else { return nil }
                return GodotRuntimeDispatcher.dynamicInvoke(target: self, selector: meta.selector, args: args)
            }
        }

        // 2. Auto-register declared @Signal property wrappers via reflection
        var currentMirror: Mirror? = Mirror(reflecting: self)
        while let mirror = currentMirror {
            for child in mirror.children {
                if let sig = child.value as? AnyGodotSignal {
                    let propName = (child.label?.hasPrefix("_") == true) ? String(child.label!.dropFirst()) : (child.label ?? "")
                    sig.bind(to: self, propertyName: propName)
                    registry.registerSignal(pluginName: name, signalName: sig.signalName)
                }
            }
            if mirror.subjectType == GodotPlugin.self { break }
            currentMirror = mirror.superclassMirror
        }

        // 3. Register declared pluginSignals (mirrors Android getPluginSignals)
        for signal in pluginSignals {
            registry.registerSignal(pluginName: name, signalName: signal.name)
        }
    }

    /// Lifecycle hook called after the plugin is registered.
    open func onInit() {}

    /// Lifecycle hook called when the plugin is deinitialized.
    open func onDeinit() {}

    /// Helper to emit signals back to Godot with variadic arguments (mirrors Android's emitSignal).
    public func emitSignal(_ signalName: String, _ args: Any...) {
        GodotPluginRegistry.shared.emitSignal(Self.pluginName, signalName: signalName, args: args)
    }

    /// Helper to emit signals back to Godot with an explicit argument array.
    public func emitSignal(_ signalName: String, args: [Any] = []) {
        GodotPluginRegistry.shared.emitSignal(Self.pluginName, signalName: signalName, args: args)
    }
}
