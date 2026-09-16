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

public final class DefaultExampleService: ExampleServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var profileName: String = "GodotDev"
    private var profileLevel: Int = 1
    private var activeSessionId: String?

    public init() {}

    public func greet(name: String) -> String {
        return "Hello, \(name)! Welcome to Godot Swift Plugin."
    }

    public func add(a: Int, b: Int) -> Int {
        return a + b
    }

    public func multiply(a: Int, b: Int) -> Int {
        return a * b
    }

    public func getUserProfile() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return [
            "name": profileName,
            "level": profileLevel,
            "is_logged_in": activeSessionId != nil,
            "coins": 1000
        ]
    }

    public func updateUserProfile(name: String, level: Int) -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        profileName = name
        profileLevel = level
        return [
            "name": profileName,
            "level": profileLevel,
            "is_logged_in": activeSessionId != nil,
            "coins": 1000
        ]
    }

    public func startSession(sessionId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        activeSessionId = sessionId
        return true
    }

    public func endSession() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard activeSessionId != nil else { return false }
        activeSessionId = nil
        return true
    }

    public func isSessionActive() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeSessionId != nil
    }
}
