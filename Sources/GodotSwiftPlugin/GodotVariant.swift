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

/// Utility handling JSON serialization and type marshaling between Godot Variants and Swift.
public enum GodotVariant {
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

    /// Encodes a Swift value into a JSON string to return to Godot.
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
