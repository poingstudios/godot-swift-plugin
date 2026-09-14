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
import CGDExtensionInterface
@testable import GodotSwiftPlugin

private final class MockPlugin: GodotPlugin {
    override class var pluginName: String { "MockPlugin" }

    var lastStatus: Int = 0
    var initialized = false

    override func onInit() {
        initialized = true
    }

    override func registerMethods(in registry: GodotPluginRegistry) {
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

@objcMembers
private final class AutoReflectedPlugin: GodotPlugin {
    override class var pluginName: String { "AutoReflected" }
    override var pluginSignals: [String] { ["data_received"] }

    var counter: Int = 100

    func get_counter() -> Int {
        return counter
    }

    func increment(_ amount: Int) {
        counter += amount
    }

    func calculate_total(_ a: Int, _ b: Int) -> Int {
        return a + b
    }

    func ping(name: String) -> String {
        return "Pong \(name)"
    }
}

final class GodotSwiftPluginTests: XCTestCase {
    override func setUp() {
        super.setUp()
        GodotPluginRegistry.shared.reset()
        GodotStringName.clearCache()
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

    func testGDExtensionInitializationEntryPoint() {
        var initialization = GDExtensionInitialization()

        let dummyGetProcAddress: GDExtensionInterfaceGetProcAddress = { name in
            return nil
        }

        let result = withUnsafeMutablePointer(to: &initialization) { initPtr in
            godot_swift_extension_init(dummyGetProcAddress, nil, initPtr)
        }

        XCTAssertEqual(result, 1)
        XCTAssertNotNil(initialization.initialize)
        XCTAssertNotNil(initialization.deinitialize)
        XCTAssertEqual(initialization.minimum_initialization_level, GDEXTENSION_INITIALIZATION_SCENE)
    }

    func testGodotStringNameCaching() {
        let sn1 = GodotStringName.cached("test_string")
        let sn2 = GodotStringName.cached("test_string")

        XCTAssertTrue(sn1 === sn2)
        XCTAssertEqual(sn1.stringValue, "test_string")

        GodotStringName.clearCache()
        let sn3 = GodotStringName.cached("test_string")
        XCTAssertFalse(sn1 === sn3)
    }

    func testGodotVariantJsonHelpers() {
        let argsJson = "[10, \"hello\", true]"
        let decoded = GodotVariant.decodeArguments(argsJson)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0] as? Int, 10)
        XCTAssertEqual(decoded[1] as? String, "hello")
        XCTAssertEqual(decoded[2] as? Bool, true)

        let encoded = GodotVariant.encodeResult(42)
        XCTAssertEqual(encoded, "42")
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

    func testAutoReflectedPlugin() {
        let plugin = AutoReflectedPlugin()
        GodotPluginRegistry.shared.registerPlugin(plugin)

        XCTAssertEqual(GodotPluginRegistry.shared.getPluginNames(), ["AutoReflected"])

        let methods = GodotPluginRegistry.shared.getMethods(for: "AutoReflected")
        XCTAssertTrue(methods.contains("get_counter"))
        XCTAssertTrue(methods.contains("getCounter"))
        XCTAssertTrue(methods.contains("increment"))
        XCTAssertTrue(methods.contains("calculate_total"))
        XCTAssertTrue(methods.contains("calculateTotal"))
        XCTAssertTrue(methods.contains("ping"))

        let signals = GodotPluginRegistry.shared.getSignals(for: "AutoReflected")
        XCTAssertTrue(signals.contains("data_received"))

        // Test calling getter
        let counterVal = GodotPluginRegistry.shared.callMethod(
            pluginName: "AutoReflected",
            methodName: "get_counter"
        ) as? Int
        XCTAssertEqual(counterVal, 100)

        // Test calling method with 1 argument
        _ = GodotPluginRegistry.shared.callMethod(
            pluginName: "AutoReflected",
            methodName: "increment",
            args: [25]
        )
        let updatedCounter = GodotPluginRegistry.shared.callMethod(
            pluginName: "AutoReflected",
            methodName: "getCounter"
        ) as? Int
        XCTAssertEqual(updatedCounter, 125)

        // Test calling method with 2 arguments
        let sum = GodotPluginRegistry.shared.callMethod(
            pluginName: "AutoReflected",
            methodName: "calculate_total",
            args: [15, 35]
        ) as? Int
        XCTAssertEqual(sum, 50)

        // Test string argument & return
        let pong = GodotPluginRegistry.shared.callMethod(
            pluginName: "AutoReflected",
            methodName: "ping",
            args: ["Godot"]
        ) as? String
        XCTAssertEqual(pong, "Pong Godot")
    }
}
