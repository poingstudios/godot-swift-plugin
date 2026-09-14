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

/// Central registry managing all registered Godot Swift plugins, methods, and signal dispatching.
public final class GodotPluginRegistry: @unchecked Sendable {
    public typealias MethodHandler = ([Any]) -> Any?

    public static let shared = GodotPluginRegistry()

    private let lock = NSRecursiveLock()
    private var plugins: [String: GodotPlugin] = [:]
    private var methods: [String: [String: MethodHandler]] = [:]
    private var signals: [String: Set<String>] = [:]

    /// Global callback invoked whenever any plugin emits a signal (for testing / listeners).
    public var onSignalEmitted: ((_ pluginName: String, _ signalName: String, _ args: [Any]) -> Void)?

    public init() {}

    /// Registers a plugin instance.
    public func registerPlugin(_ plugin: GodotPlugin) {
        lock.lock()
        defer { lock.unlock() }

        let name = type(of: plugin).pluginName
        plugins[name] = plugin
        if methods[name] == nil {
            methods[name] = [:]
        }
        if signals[name] == nil {
            signals[name] = []
        }

        plugin.registerMethods(in: self)
        plugin.onInit()

        // If the engine interface is already loaded, register in ClassDB immediately
        if GodotInterface.shared.isInitialized {
            GodotClassDB.shared.registerPlugin(plugin)
        }
    }

    /// Registers a method for a specific plugin.
    public func registerMethod(pluginName: String, methodName: String, handler: @escaping MethodHandler) {
        lock.lock()
        defer { lock.unlock() }

        if methods[pluginName] == nil {
            methods[pluginName] = [:]
        }
        methods[pluginName]?[methodName] = handler
    }

    /// Declares a signal for a specific plugin.
    public func registerSignal(pluginName: String, signalName: String) {
        lock.lock()
        defer { lock.unlock() }

        if signals[pluginName] == nil {
            signals[pluginName] = []
        }
        signals[pluginName]?.insert(signalName)
    }

    /// Invokes a registered method by plugin and method name with automatic camelCase / snake_case aliasing.
    public func callMethod(pluginName: String, methodName: String, args: [Any] = []) -> Any? {
        lock.lock()
        defer { lock.unlock() }

        guard let pluginMethods = methods[pluginName] else {
            return nil
        }

        // 1. Direct match
        if let handler = pluginMethods[methodName] {
            return handler(args)
        }

        // 2. Try camelCase if GDScript called with snake_case
        let camelName = Self.snakeToCamelCase(methodName)
        if let handler = pluginMethods[camelName] {
            return handler(args)
        }

        // 3. Try snake_case if called with camelCase
        let snakeName = Self.camelToSnakeCase(methodName)
        if let handler = pluginMethods[snakeName] {
            return handler(args)
        }

        return nil
    }

    /// Emits a signal from a plugin to listeners and the Godot Engine.
    public func emitSignal(_ pluginName: String, signalName: String, args: [Any] = []) {
        // Dispatch to Godot Engine ClassDB object
        GodotClassDB.shared.emitSignal(pluginName: pluginName, signalName: signalName, args: args)

        // Dispatch to testing / observer callback
        onSignalEmitted?(pluginName, signalName, args)
    }

    /// Automatically discovers and registers GodotPlugin subclasses present in the runtime.
    public func discoverAndRegisterPlugins() {
        lock.lock()
        let hasPlugins = !plugins.isEmpty
        lock.unlock()

        if hasPlugins {
            return
        }

        // 1. Check Info.plist for explicitly named plugin class
        var explicitClasses: [String] = []
        if let mainClassName = Bundle.main.object(forInfoDictionaryKey: "GodotPluginClass") as? String {
            explicitClasses.append(mainClassName)
        }
        for bundle in Bundle.allFrameworks {
            if let frameworkClassName = bundle.object(forInfoDictionaryKey: "GodotPluginClass") as? String {
                explicitClasses.append(frameworkClassName)
            }
        }

        for className in explicitClasses {
            if let cls = NSClassFromString(className) as? GodotPlugin.Type {
                let plugin = cls.init()
                registerPlugin(plugin)
            }
        }

        // 2. Discover all subclasses of GodotPlugin via Objective-C runtime
        let discoveredTypes = GodotRuntimeDispatcher.discoverPluginClasses()
        for pluginType in discoveredTypes {
            let name = pluginType.pluginName
            lock.lock()
            let alreadyRegistered = plugins[name] != nil
            lock.unlock()

            if !alreadyRegistered {
                let plugin = pluginType.init()
                registerPlugin(plugin)
            }
        }
    }

    /// Initializes all registered plugins with Godot ClassDB.
    public func initializeAllPlugins() {
        discoverAndRegisterPlugins()

        lock.lock()
        let activePlugins = Array(plugins.values)
        lock.unlock()

        for plugin in activePlugins {
            if !GodotClassDB.shared.isRegistered(plugin) {
                GodotClassDB.shared.registerPlugin(plugin)
            }
        }
    }

    /// Deinitializes all registered plugins.
    public func deinitializeAllPlugins() {
        lock.lock()
        let activePlugins = Array(plugins.values)
        lock.unlock()

        for plugin in activePlugins {
            plugin.onDeinit()
        }
    }

    /// Returns list of all registered plugin names.
    public func getPluginNames() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(plugins.keys)
    }

    /// Returns list of all method names for a plugin (includes both snake_case and camelCase aliases).
    public func getMethods(for pluginName: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let methodDict = methods[pluginName] else {
            return []
        }
        var allNames = Set<String>()
        for name in methodDict.keys {
            allNames.insert(name)
            allNames.insert(Self.camelToSnakeCase(name))
            allNames.insert(Self.snakeToCamelCase(name))
        }
        return Array(allNames)
    }

    /// Returns list of all signal names for a plugin.
    public func getSignals(for pluginName: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let signalSet = signals[pluginName] else {
            return []
        }
        return Array(signalSet)
    }

    /// Clears all registrations (useful for testing).
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        plugins.removeAll()
        methods.removeAll()
        signals.removeAll()
        onSignalEmitted = nil
    }

    // MARK: - Case Conversion Helpers

    public static func snakeToCamelCase(_ string: String) -> String {
        let parts = string.split(separator: "_")
        guard let first = parts.first else { return string }
        let rest = parts.dropFirst().map { $0.capitalized }
        return ([String(first)] + rest).joined()
    }

    public static func camelToSnakeCase(_ string: String) -> String {
        var result = ""
        for (i, char) in string.enumerated() {
            if char.isUppercase {
                if i > 0 {
                    result.append("_")
                }
                result.append(char.lowercased())
            } else {
                result.append(char)
            }
        }
        return result
    }
}
