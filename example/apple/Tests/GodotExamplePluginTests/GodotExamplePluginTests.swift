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

import XCTest
import GodotSwiftPlugin
@testable import GodotExamplePlugin

final class MockExampleService: ExampleServiceProtocol, @unchecked Sendable {
    var greetCalled = false
    var addCalled = false
    var profileCalled = false
    var sessionStarted = false
    var sessionEnded = false

    func greet(name: String) -> String {
        greetCalled = true
        return "Mock Hello, \(name)"
    }

    func add(a: Int, b: Int) -> Int {
        addCalled = true
        return a + b + 100
    }

    func multiply(a: Int, b: Int) -> Int {
        return a * b
    }

    func getUserProfile() -> [String: Any] {
        profileCalled = true
        return ["name": "MockUser", "level": 99]
    }

    func updateUserProfile(name: String, level: Int) -> [String: Any] {
        return ["name": name, "level": level]
    }

    func startSession(sessionId: String) -> Bool {
        sessionStarted = true
        return true
    }

    func endSession() -> Bool {
        sessionEnded = true
        return true
    }

    func isSessionActive() -> Bool {
        return sessionStarted && !sessionEnded
    }
}

final class GodotExamplePluginTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GodotPluginRegistry.shared.reset()
    }

    override func tearDown() {
        GodotPluginRegistry.shared.reset()
        super.tearDown()
    }

    func testDefaultServiceOperations() {
        let plugin = GodotExamplePlugin()
        GodotPluginRegistry.shared.registerPlugin(plugin)

        let greeting = plugin.ping(message: "Antigravity")
        XCTAssertTrue(greeting.contains("Antigravity"))

        let sum = plugin.add_numbers(a: 10, b: 20)
        XCTAssertEqual(sum, 30)

        let product = plugin.multiply_numbers(a: 6, b: 7)
        XCTAssertEqual(product, 42)

        let profile = plugin.get_user_profile()
        XCTAssertEqual(profile["name"] as? String, "GodotDev")
        XCTAssertEqual(profile["level"] as? Int, 1)

        let updated = plugin.update_user_profile(name: "SwiftMaster", level: 10)
        XCTAssertEqual(updated["name"] as? String, "SwiftMaster")
        XCTAssertEqual(updated["level"] as? Int, 10)

        XCTAssertFalse(plugin.is_session_active())
        XCTAssertTrue(plugin.start_session(sessionId: "session-123"))
        XCTAssertTrue(plugin.is_session_active())
        XCTAssertTrue(plugin.end_session())
        XCTAssertFalse(plugin.is_session_active())
    }

    func testDependencyInversionWithMockService() {
        let mock = MockExampleService()
        let plugin = GodotExamplePlugin(service: mock)
        GodotPluginRegistry.shared.registerPlugin(plugin)

        let greeting = plugin.ping(message: "Tester")
        XCTAssertTrue(mock.greetCalled)
        XCTAssertEqual(greeting, "Mock Hello, Tester")

        let sum = plugin.add_numbers(a: 5, b: 5)
        XCTAssertTrue(mock.addCalled)
        XCTAssertEqual(sum, 110)

        let profile = plugin.get_user_profile()
        XCTAssertTrue(mock.profileCalled)
        XCTAssertEqual(profile["name"] as? String, "MockUser")

        _ = plugin.start_session(sessionId: "mock-session")
        XCTAssertTrue(mock.sessionStarted)
    }

    func testSignalsEmittedThroughRegistry() {
        let plugin = GodotExamplePlugin()
        GodotPluginRegistry.shared.registerPlugin(plugin)

        var emittedSignals: [(name: String, args: [Any])] = []
        GodotPluginRegistry.shared.onSignalEmitted = { pluginName, signalName, args in
            if pluginName == "Example" {
                emittedSignals.append((signalName, args))
            }
        }

        plugin.trigger_session_end_signal()
        plugin.trigger_score_signal(score: 42)
        plugin.trigger_profile_signal()

        XCTAssertEqual(emittedSignals.count, 3)
        XCTAssertEqual(emittedSignals[0].name, "session_ended")
        XCTAssertTrue(emittedSignals[0].args.isEmpty)

        XCTAssertEqual(emittedSignals[1].name, "score_calculated")
        XCTAssertEqual(emittedSignals[1].args.first as? Int, 42)

        XCTAssertEqual(emittedSignals[2].name, "user_profile_updated")
        let dict = emittedSignals[2].args.first as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["name"] as? String, "GodotDev")
    }
}
