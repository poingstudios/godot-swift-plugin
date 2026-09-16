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
import GodotSwiftPlugin

public final class GodotExamplePlugin: GodotPlugin {
    public override class var pluginName: String { "Example" }

    @Signal
    public var sessionEnded

    @Signal
    public var userProfileUpdated

    @Signal
    public var scoreCalculated

    private let service: ExampleServiceProtocol

    public required init() {
        self.service = DefaultExampleService()
        super.init()
    }

    public init(service: ExampleServiceProtocol) {
        self.service = service
        super.init()
    }

    // MARK: - Greeting Service

    @objc public func ping(message: String) -> String {
        return service.greet(name: message)
    }

    // MARK: - Calculation Service

    @objc public func add_numbers(a: Int, b: Int) -> Int {
        let result = service.add(a: a, b: b)
        scoreCalculated.emit(result, "add")
        return result
    }

    @objc public func multiply_numbers(a: Int, b: Int) -> Int {
        let result = service.multiply(a: a, b: b)
        scoreCalculated.emit(result, "multiply")
        return result
    }

    // MARK: - User Profile Service

    @objc public func get_user_profile() -> [String: Any] {
        return service.getUserProfile()
    }

    @objc public func update_user_profile(name: String, level: Int) -> [String: Any] {
        let updated = service.updateUserProfile(name: name, level: level)
        userProfileUpdated.emit(updated)
        return updated
    }

    // MARK: - Session Service

    @objc public func start_session(sessionId: String) -> Bool {
        return service.startSession(sessionId: sessionId)
    }

    @objc public func end_session() -> Bool {
        let ended = service.endSession()
        if ended {
            sessionEnded.emit()
        }
        return ended
    }

    @objc public func is_session_active() -> Bool {
        return service.isSessionActive()
    }

    // MARK: - Manual Trigger Test Helpers

    @objc public func trigger_profile_signal() {
        userProfileUpdated.emit(service.getUserProfile())
    }

    @objc public func trigger_score_signal(score: Int) {
        scoreCalculated.emit(score, "manual")
    }

    @objc public func trigger_session_end_signal() {
        sessionEnded.emit()
    }
}
