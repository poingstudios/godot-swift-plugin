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

/// Safe wrapper for a native Godot StringName instance.
public final class GodotStringName {
    private static let lock = NSLock()
    private static var cache: [String: GodotStringName] = [:]

    private var storage: (UInt64, UInt64) = (0, 0)
    public let stringValue: String

    public init(_ string: String) {
        self.stringValue = string
        if let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil {
            string.withCString { cstr in
                withUnsafeMutablePointer(to: &storage) { ptr in
                    gi.string_name_new_with_utf8_chars?(ptr, cstr)
                }
            }
        }
    }

    /// Obtains a cached StringName or creates a new one.
    public static func cached(_ string: String) -> GodotStringName {
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[string] {
            return existing
        }
        let created = GodotStringName(string)
        cache[string] = created
        return created
    }

    /// Clears the global StringName cache.
    public static func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    /// Executes a closure with a const pointer to the raw StringName.
    public func withUnsafeRawPointer<R>(_ body: (GDExtensionConstStringNamePtr) throws -> R) rethrows -> R {
        return try withUnsafePointer(to: &storage) { ptr in
            try body(ptr)
        }
    }

    /// Executes a closure with a mutable pointer to the raw StringName.
    public func withUnsafeMutableRawPointer<R>(_ body: (GDExtensionStringNamePtr) throws -> R) rethrows -> R {
        return try withUnsafeMutablePointer(to: &storage) { ptr in
            try body(ptr)
        }
    }

    deinit {
        if let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil {
            withUnsafeMutablePointer(to: &storage) { ptr in
                gi.stringNameDestructor?(ptr)
            }
        }
    }
}
