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

public typealias GodotSignalCallback = @convention(c) (
    UnsafePointer<CChar>, // pluginName
    UnsafePointer<CChar>, // signalName
    UnsafePointer<CChar>  // jsonArgs
) -> Void

private var globalSignalCallback: GodotSignalCallback?

/// Helper to allocate a C-string that Godot's C++ side can read.
private func makeCString(_ string: String) -> UnsafePointer<CChar> {
    return UnsafePointer(strdup(string))
}

@_cdecl("godot_swift_free_string")
public func godot_swift_free_string(_ ptr: UnsafePointer<CChar>?) {
    if let ptr {
        free(UnsafeMutableRawPointer(mutating: ptr))
    }
}

@_cdecl("godot_swift_set_signal_callback")
public func godot_swift_set_signal_callback(_ callback: GodotSignalCallback?) {
    globalSignalCallback = callback

    GodotPluginRegistry.shared.onSignalEmitted = { pluginName, signalName, args in
        guard let callback = globalSignalCallback else { return }

        let jsonArgs = GodotVariant.encodeSignalArgs(args)
        pluginName.withCString { cPlugin in
            signalName.withCString { cSignal in
                jsonArgs.withCString { cArgs in
                    callback(cPlugin, cSignal, cArgs)
                }
            }
        }
    }
}

@_cdecl("godot_swift_get_plugin_count")
public func godot_swift_get_plugin_count() -> Int32 {
    return Int32(GodotPluginRegistry.shared.getPluginNames().count)
}

@_cdecl("godot_swift_get_plugin_name")
public func godot_swift_get_plugin_name(_ index: Int32) -> UnsafePointer<CChar>? {
    let names = GodotPluginRegistry.shared.getPluginNames()
    let idx = Int(index)
    guard idx >= 0 && idx < names.count else { return nil }
    return makeCString(names[idx])
}

@_cdecl("godot_swift_get_methods")
public func godot_swift_get_methods(_ cPluginName: UnsafePointer<CChar>) -> UnsafePointer<CChar>? {
    let pluginName = String(cString: cPluginName)
    let methods = GodotPluginRegistry.shared.getMethods(for: pluginName)
    let json = GodotVariant.encodeResult(methods)
    return makeCString(json)
}

@_cdecl("godot_swift_get_signals")
public func godot_swift_get_signals(_ cPluginName: UnsafePointer<CChar>) -> UnsafePointer<CChar>? {
    let pluginName = String(cString: cPluginName)
    let signals = GodotPluginRegistry.shared.getSignals(for: pluginName)
    let json = GodotVariant.encodeResult(signals)
    return makeCString(json)
}

@_cdecl("godot_swift_call_method")
public func godot_swift_call_method(
    _ cPluginName: UnsafePointer<CChar>,
    _ cMethodName: UnsafePointer<CChar>,
    _ cJsonArgs: UnsafePointer<CChar>
) -> UnsafePointer<CChar>? {
    let pluginName = String(cString: cPluginName)
    let methodName = String(cString: cMethodName)
    let jsonArgs = String(cString: cJsonArgs)

    let args = GodotVariant.decodeArguments(jsonArgs)
    let result = GodotPluginRegistry.shared.callMethod(pluginName: pluginName, methodName: methodName, args: args)
    let encodedResult = GodotVariant.encodeResult(result)
    return makeCString(encodedResult)
}
