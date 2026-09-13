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

/// Base protocol for all native Godot iOS/Apple plugins written in Swift.
public protocol GodotPlugin: AnyObject {
    /// The unique singleton name registered in Godot Engine.
    static var pluginName: String { get }

    /// Lifecycle hook called when the plugin is initialized.
    func onInit()

    /// Method registry registration hook.
    func registerMethods(in registry: GodotPluginRegistry)
}

public extension GodotPlugin {
    func onInit() {}
}

/// Registry mapping method names to Swift closures and emitting signals to Godot.
public final class GodotPluginRegistry {
    public typealias MethodHandler = ([Any]) -> Any?

    private var methods: [String: MethodHandler] = [:]
    public var onSignalEmitted: ((String, Any?) -> Void)?

    public init() {}

    /// Registers a callable method by name.
    public func register(_ methodName: String, handler: @escaping MethodHandler) {
        methods[methodName] = handler
    }

    /// Calls a registered method by name.
    public func call(method: String, args: [Any] = []) -> Any? {
        guard let handler = methods[method] else {
            return nil
        }
        return handler(args)
    }

    /// Emits a signal back to Godot.
    public func emit(signal: String, data: Any? = nil) {
        onSignalEmitted?(signal, data)
    }
}
