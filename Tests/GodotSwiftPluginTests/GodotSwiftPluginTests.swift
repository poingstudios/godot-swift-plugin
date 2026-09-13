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
@testable import GodotSwiftPlugin

private final class MockPlugin: GodotPlugin {
    static let pluginName = "MockPlugin"

    var lastStatus: Int = 0
    var initialized = false

    func onInit() {
        initialized = true
    }

    func registerMethods(in registry: GodotPluginRegistry) {
        // Registered with idiomatic Swift camelCase:
        registry.registerMethod(pluginName: Self.pluginName, methodName: "getStatus") { [weak self] _ in
            return self?.lastStatus ?? 0
        }

        registry.registerMethod(pluginName: Self.pluginName, methodName: "setStatus") { [weak self] args in
            if let first = args.first as? Int {
                self?.lastStatus = first
            }
            return nil
        }

        registry.registerMethod(pluginName: Self.pluginName, methodName: "addNumbers") { args in
            let a = (args[0] as? Int) ?? 0
            let b = (args[1] as? Int) ?? 0
            return a + b
        }

        registry.registerSignal(pluginName: Self.pluginName, signalName: "status_changed")
    }

    func triggerSignal(status: Int) {
        emitSignal("status_changed", args: [status])
    }
}

final class GodotSwiftPluginTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GodotPluginRegistry.shared.reset()
    }

    func testPluginRegistrationAndLifecycle() {
        let plugin = MockPlugin()
        GodotPluginRegistry.shared.registerPlugin(plugin)

        XCTAssertTrue(plugin.initialized)
        XCTAssertEqual(GodotPluginRegistry.shared.getPluginNames(), ["MockPlugin"])
        XCTAssertTrue(GodotPluginRegistry.shared.getMethods(for: "MockPlugin").contains("get_status"))
        XCTAssertTrue(GodotPluginRegistry.shared.getMethods(for: "MockPlugin").contains("getStatus"))
        XCTAssertTrue(GodotPluginRegistry.shared.getSignals(for: "MockPlugin").contains("status_changed"))
    }

    func testMethodCallWithSnakeCaseAlias() {
        let plugin = MockPlugin()
        GodotPluginRegistry.shared.registerPlugin(plugin)

        // Swift registered "getStatus", GDScript calls "get_status"
        let initialStatus = GodotPluginRegistry.shared.callMethod(pluginName: "MockPlugin", methodName: "get_status") as? Int
        XCTAssertEqual(initialStatus, 0)

        // Swift registered "setStatus", GDScript calls "set_status"
        _ = GodotPluginRegistry.shared.callMethod(pluginName: "MockPlugin", methodName: "set_status", args: [42])
        let updatedStatus = GodotPluginRegistry.shared.callMethod(pluginName: "MockPlugin", methodName: "get_status") as? Int
        XCTAssertEqual(updatedStatus, 42)

        // Swift registered "addNumbers", GDScript calls "add_numbers"
        let sum = GodotPluginRegistry.shared.callMethod(pluginName: "MockPlugin", methodName: "add_numbers", args: [10, 25]) as? Int
        XCTAssertEqual(sum, 35)
    }

    func testSignalEmission() {
        let plugin = MockPlugin()
        GodotPluginRegistry.shared.registerPlugin(plugin)

        var receivedPlugin: String?
        var receivedSignal: String?
        var receivedArgs: [Any]?

        GodotPluginRegistry.shared.onSignalEmitted = { pName, sName, args in
            receivedPlugin = pName
            receivedSignal = sName
            receivedArgs = args
        }

        plugin.triggerSignal(status: 3)

        XCTAssertEqual(receivedPlugin, "MockPlugin")
        XCTAssertEqual(receivedSignal, "status_changed")
        XCTAssertEqual(receivedArgs?.first as? Int, 3)
    }

    func testCBridgeFunctions() {
        let plugin = MockPlugin()
        GodotPluginRegistry.shared.registerPlugin(plugin)

        XCTAssertEqual(godot_swift_get_plugin_count(), 1)

        if let cName = godot_swift_get_plugin_name(0) {
            XCTAssertEqual(String(cString: cName), "MockPlugin")
            godot_swift_free_string(cName)
        } else {
            XCTFail("Missing plugin name")
        }

        let cPluginName = ("MockPlugin" as NSString).utf8String!
        let cMethodName = ("add_numbers" as NSString).utf8String!
        let cArgs = ("[15, 27]" as NSString).utf8String!

        if let resultPtr = godot_swift_call_method(cPluginName, cMethodName, cArgs) {
            let resultStr = String(cString: resultPtr)
            XCTAssertEqual(resultStr, "42")
            godot_swift_free_string(resultPtr)
        } else {
            XCTFail("Method call returned nil")
        }
    }

    func testGodotOSFocusHooks() {
        var focusOutCalled = false
        var focusInCalled = false

        GodotOS.customFocusOutHandler = {
            focusOutCalled = true
        }
        GodotOS.customFocusInHandler = {
            focusInCalled = true
        }

        GodotOS.onFocusOut()
        XCTAssertTrue(focusOutCalled)

        GodotOS.onFocusIn()
        XCTAssertTrue(focusInCalled)

        GodotOS.customFocusOutHandler = nil
        GodotOS.customFocusInHandler = nil
    }
}
