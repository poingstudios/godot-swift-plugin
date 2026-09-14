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

/// Internal protocol enabling runtime discovery and binding of `@Signal` properties.
public protocol AnyGodotSignal: AnyObject {
    var signalName: String { get }
    func bind(to plugin: GodotPlugin, propertyName: String)
}

/// A lightweight, type-safe property wrapper for declaring and emitting Godot signals.
///
/// Can be used untyped (`@Signal`) or strongly typed (`@Signal<Int>`, `@Signal<Void>`, `@Signal<(Int, String)>`).
///
/// Example:
/// ```swift
/// public class MyPlugin: GodotPlugin {
///     @Signal
///     var onCompleted: Signal<Void> // or @Signal<Void> var onCompleted
///
///     @Signal<Int>
///     var onStatusChanged
///
///     @Signal
///     var onGenericEvent
///
///     func finish() {
///         onCompleted.emit()
///         onStatusChanged.emit(1)
///         onGenericEvent.emit(["key": "value"])
///     }
/// }
/// ```
@propertyWrapper
public final class Signal: AnyGodotSignal {
    public private(set) var signalName: String
    private weak var plugin: GodotPlugin?

    public init(_ name: String? = nil) {
        self.signalName = name ?? ""
    }

    public var wrappedValue: Signal {
        return self
    }

    public func bind(to plugin: GodotPlugin, propertyName: String) {
        self.plugin = plugin
        if signalName.isEmpty {
            self.signalName = GodotPluginRegistry.camelToSnakeCase(propertyName)
        }
    }

    /// Emits a parameterless signal.
    public func emit() {
        plugin?.emitSignal(signalName, args: [])
    }

    /// Emits a signal with a single argument (e.g. Int, String, Dictionary, Array).
    public func emit(_ arg: Any) {
        plugin?.emitSignal(signalName, args: [arg])
    }

    /// Emits a signal with multiple arguments.
    public func emit(_ arg1: Any, _ arg2: Any, _ rest: Any...) {
        var allArgs: [Any] = [arg1, arg2]
        allArgs.append(contentsOf: rest)
        plugin?.emitSignal(signalName, args: allArgs)
    }

    /// Emits a signal with an explicit array of arguments.
    public func emit(args: [Any]) {
        plugin?.emitSignal(signalName, args: args)
    }
}

/// A property wrapper for declaring strictly typed Godot signals.
@propertyWrapper
public final class TypedSignal<Args>: AnyGodotSignal {
    public private(set) var signalName: String
    private weak var plugin: GodotPlugin?

    public init(_ name: String? = nil) {
        self.signalName = name ?? ""
    }

    public var wrappedValue: TypedSignal<Args> {
        return self
    }

    public func bind(to plugin: GodotPlugin, propertyName: String) {
        self.plugin = plugin
        if signalName.isEmpty {
            self.signalName = GodotPluginRegistry.camelToSnakeCase(propertyName)
        }
    }

    /// Emits the signal with strongly typed argument(s).
    public func emit(_ arg: Args) {
        let mirror = Mirror(reflecting: arg)
        if mirror.displayStyle == .tuple {
            let tupleArgs = mirror.children.map { $0.value }
            plugin?.emitSignal(signalName, args: tupleArgs)
            return
        }
        plugin?.emitSignal(signalName, args: [arg])
    }
}

extension TypedSignal where Args == Void {
    /// Emits a parameterless typed signal.
    public func emit() {
        plugin?.emitSignal(signalName, args: [])
    }
}


