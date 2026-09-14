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
import CGDExtensionInterface

/// An aligned in-memory storage buffer sufficient for holding any Godot Variant.
public struct GodotVariantBuffer {
    // 64 bytes aligned to 8 bytes safely accommodates Variant across all Godot precision targets.
    private var data: (UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0, 0, 0, 0, 0)

    public init() {}

    public mutating func withUnsafeMutableRawPointer<R>(_ body: (GDExtensionVariantPtr) throws -> R) rethrows -> R {
        return try withUnsafeMutableBytes(of: &data) { rawPtr in
            try body(rawPtr.baseAddress!)
        }
    }

    public func withUnsafeRawPointer<R>(_ body: (GDExtensionConstVariantPtr) throws -> R) rethrows -> R {
        return try withUnsafeBytes(of: data) { rawPtr in
            try body(rawPtr.baseAddress!)
        }
    }
}

/// Utility handling type marshaling between native Godot Variants and Swift.
public enum GodotVariant {
    // MARK: - Native GDExtension Marshaling

    /// Converts a raw Godot Variant pointer into a native Swift value.
    public static func toSwift(_ variantPtr: GDExtensionConstVariantPtr) -> Any? {
        guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil,
              let getType = gi.variant_get_type else {
            return nil
        }

        let type = getType(variantPtr)
        switch type {
        case GDEXTENSION_VARIANT_TYPE_NIL:
            return nil

        case GDEXTENSION_VARIANT_TYPE_BOOL:
            guard let fromVariant = gi.boolFromVariant else { return nil }
            var val: UInt8 = 0
            fromVariant(&val, UnsafeMutableRawPointer(mutating: variantPtr))
            return val != 0

        case GDEXTENSION_VARIANT_TYPE_INT:
            guard let fromVariant = gi.intFromVariant else { return nil }
            var val: Int64 = 0
            fromVariant(&val, UnsafeMutableRawPointer(mutating: variantPtr))
            return Int(val)

        case GDEXTENSION_VARIANT_TYPE_FLOAT:
            guard let fromVariant = gi.floatFromVariant else { return nil }
            var val: Double = 0
            fromVariant(&val, UnsafeMutableRawPointer(mutating: variantPtr))
            return val

        case GDEXTENSION_VARIANT_TYPE_STRING:
            guard let fromVariant = gi.stringFromVariant,
                  let toUtf8 = gi.string_to_utf8_chars else { return nil }
            var strBuf: (UInt64, UInt64) = (0, 0)
            fromVariant(&strBuf, UnsafeMutableRawPointer(mutating: variantPtr))
            defer {
                withUnsafeMutablePointer(to: &strBuf) { ptr in
                    gi.stringDestructor?(ptr)
                }
            }
            let len = withUnsafeMutablePointer(to: &strBuf) { ptr in
                toUtf8(ptr, nil, 0)
            }
            if len <= 0 { return "" }
            var cChars = [CChar](repeating: 0, count: Int(len) + 1)
            withUnsafeMutablePointer(to: &strBuf) { ptr in
                _ = toUtf8(ptr, &cChars, len)
            }
            return String(cString: cChars)

        default:
            return nil
        }
    }

    /// Converts an array of Godot Variant pointers to an array of Swift values.
    public static func toSwiftArray(
        args: UnsafePointer<GDExtensionConstVariantPtr?>?,
        count: Int
    ) -> [Any] {
        guard let args, count > 0 else { return [] }
        var result: [Any] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            if let optPtr = args[i], let val = toSwift(optPtr) {
                result.append(val)
            } else {
                result.append(NSNull())
            }
        }
        return result
    }

    /// Writes a Swift value directly into a Godot Variant memory destination.
    public static func writeVariant(_ value: Any?, to destPtr: GDExtensionVariantPtr) {
        guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil else { return }

        guard let value, !(value is NSNull) else {
            gi.variant_new_nil?(destPtr)
            return
        }

        switch value {
        case let b as Bool:
            guard let fromType = gi.variantFromBool else { return }
            var val: UInt8 = b ? 1 : 0
            fromType(destPtr, &val)

        case let i as Int:
            guard let fromType = gi.variantFromInt else { return }
            var val: Int64 = Int64(i)
            fromType(destPtr, &val)

        case let i as Int64:
            guard let fromType = gi.variantFromInt else { return }
            var val = i
            fromType(destPtr, &val)

        case let d as Double:
            guard let fromType = gi.variantFromFloat else { return }
            var val = d
            fromType(destPtr, &val)

        case let f as Float:
            guard let fromType = gi.variantFromFloat else { return }
            var val = Double(f)
            fromType(destPtr, &val)

        case let s as String:
            guard let fromType = gi.variantFromString,
                  let newString = gi.string_new_with_utf8_chars else { return }
            var strBuf: (UInt64, UInt64) = (0, 0)
            s.withCString { cstr in
                withUnsafeMutablePointer(to: &strBuf) { ptr in
                    newString(ptr, cstr)
                }
            }
            defer {
                withUnsafeMutablePointer(to: &strBuf) { ptr in
                    gi.stringDestructor?(ptr)
                }
            }
            withUnsafeMutablePointer(to: &strBuf) { ptr in
                fromType(destPtr, ptr)
            }

        default:
            gi.variant_new_nil?(destPtr)
        }
    }

    // MARK: - Legacy / Test Harness JSON Marshaling

    /// Decodes a JSON string into an array of arguments for method dispatch.
    public static func decodeArguments(_ jsonString: String) -> [Any] {
        guard !jsonString.isEmpty, let data = jsonString.data(using: .utf8) else {
            return []
        }
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let array = json as? [Any] else {
            return []
        }
        return array
    }

    /// Encodes a Swift value into a JSON string.
    public static func encodeResult(_ value: Any?) -> String {
        guard let value else {
            return "null"
        }

        if let string = value as? String {
            return escapeString(string)
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let num = value as? NSNumber {
            return num.stringValue
        } else if let int = value as? Int {
            return String(int)
        } else if let double = value as? Double {
            return String(double)
        } else if let float = value as? Float {
            return String(float)
        }

        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: []),
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return escapeString(String(describing: value))
    }

    /// Encodes an array of signal arguments into a JSON string.
    public static func encodeSignalArgs(_ args: [Any]) -> String {
        guard JSONSerialization.isValidJSONObject(args),
              let data = try? JSONSerialization.data(withJSONObject: args, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func escapeString(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string], options: []),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2 else {
            return "\"\(string)\""
        }
        let inner = json.dropFirst().dropLast()
        return String(inner)
    }
}
