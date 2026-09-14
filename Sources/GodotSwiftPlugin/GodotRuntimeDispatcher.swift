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
import ObjectiveC

/// Dispatches method calls dynamically to @objc annotated methods using Objective-C runtime introspection.
public enum GodotRuntimeDispatcher {
    private static let invClass: AnyClass? = NSClassFromString("NSInvocation")
    private static let sigSel = NSSelectorFromString("methodSignatureForSelector:")
    private static let invSel = NSSelectorFromString("invocationWithMethodSignature:")
    private static let setSelSel = NSSelectorFromString("setSelector:")
    private static let setTargetSel = NSSelectorFromString("setTarget:")
    private static let setArgSel = NSSelectorFromString("setArgument:atIndex:")
    private static let numArgsSel = NSSelectorFromString("numberOfArguments")
    private static let argTypeSel = NSSelectorFromString("getArgumentTypeAtIndex:")
    private static let invokeSel = NSSelectorFromString("invoke")
    private static let retLenSel = NSSelectorFromString("methodReturnLength")
    private static let retTypeSel = NSSelectorFromString("methodReturnType")
    private static let getRetSel = NSSelectorFromString("getReturnValue:")

    /// Cached set of selector names to ignore during auto-discovery.
    private static let ignoredSelectors: Set<String> = {
        var names = Set<String>()
        func collect(from cls: AnyClass) {
            var count: UInt32 = 0
            if let list = class_copyMethodList(cls, &count) {
                defer { free(list) }
                for i in 0..<Int(count) {
                    names.insert(NSStringFromSelector(method_getName(list[i])))
                }
            }
        }
        collect(from: NSObject.self)
        collect(from: GodotPlugin.self)
        names.insert(".cxx_destruct")
        names.insert("dealloc")
        names.insert("init")
        return names
    }()

    /// Discovers all subclasses of GodotPlugin loaded into the current process.
    public static func discoverPluginClasses() -> [GodotPlugin.Type] {
        var found: [GodotPlugin.Type] = []
        let expectedBase: AnyClass = GodotPlugin.self

        let numClasses = objc_getClassList(nil, 0)
        guard numClasses > 0 else { return [] }

        let classes = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(numClasses))
        defer { classes.deallocate() }

        let actualCount = objc_getClassList(AutoreleasingUnsafeMutablePointer(classes), numClasses)
        for i in 0..<Int(actualCount) {
            let cls: AnyClass = classes[i]
            var sup: AnyClass? = class_getSuperclass(cls)
            while let s = sup {
                if s == expectedBase {
                    if let pluginType = cls as? GodotPlugin.Type {
                        found.append(pluginType)
                    }
                    break
                }
                sup = class_getSuperclass(s)
            }
        }
        return found
    }

    /// Discovers all candidate @objc methods on a plugin instance.
    public static func discoverMethods(for plugin: GodotPlugin) -> [String: Selector] {
        var result: [String: Selector] = [:]
        var count: UInt32 = 0

        guard let list = class_copyMethodList(type(of: plugin), &count) else {
            return [:]
        }
        defer { free(list) }

        for i in 0..<Int(count) {
            let sel = method_getName(list[i])
            let selName = NSStringFromSelector(sel)

            if ignoredSelectors.contains(selName) || selName.hasPrefix(".") {
                continue
            }

            // Extract base method name (strip colon-delimited parameters if present)
            let baseName: String
            if let firstColon = selName.firstIndex(of: ":") {
                baseName = String(selName[..<firstColon])
            } else {
                baseName = selName
            }

            result[baseName] = sel

            // If baseName contains "With" (e.g. "pingWithName" -> "ping"), also register pure name
            if let withRange = baseName.range(of: "With") {
                let pureName = String(baseName[..<withRange.lowerBound])
                if !pureName.isEmpty {
                    result[pureName] = sel
                }
            }
        }

        return result
    }

    /// Invokes a selector dynamically on target with the provided arguments.
    public static func dynamicInvoke(target: NSObject, selector: Selector, args: [Any]) -> Any? {
        guard let invClass else { return nil }

        // 1. Obtain method signature
        guard let sigImp = class_getMethodImplementation(type(of: target), sigSel) else {
            return nil
        }
        typealias SigFunc = @convention(c) (AnyObject, Selector, Selector) -> AnyObject?
        guard let sig = unsafeBitCast(sigImp, to: SigFunc.self)(target, sigSel, selector) else {
            return nil
        }

        // 2. Create NSInvocation
        guard let invImp = class_getMethodImplementation(object_getClass(invClass), invSel) else {
            return nil
        }
        typealias InvFunc = @convention(c) (AnyClass, Selector, AnyObject) -> AnyObject?
        guard let invocation = unsafeBitCast(invImp, to: InvFunc.self)(invClass, invSel, sig) else {
            return nil
        }

        // 3. Configure invocation target & selector
        if let imp = class_getMethodImplementation(type(of: invocation), setSelSel) {
            typealias SetSelFunc = @convention(c) (AnyObject, Selector, Selector) -> Void
            unsafeBitCast(imp, to: SetSelFunc.self)(invocation, setSelSel, selector)
        }

        if let imp = class_getMethodImplementation(type(of: invocation), setTargetSel) {
            typealias SetTargetFunc = @convention(c) (AnyObject, Selector, AnyObject) -> Void
            unsafeBitCast(imp, to: SetTargetFunc.self)(invocation, setTargetSel, target)
        }

        // 4. Pass arguments
        guard let setArgImp = class_getMethodImplementation(type(of: invocation), setArgSel),
              let numArgsImp = class_getMethodImplementation(type(of: sig), numArgsSel),
              let argTypeImp = class_getMethodImplementation(type(of: sig), argTypeSel) else {
            return nil
        }

        typealias SetArgFunc = @convention(c) (AnyObject, Selector, UnsafeRawPointer, Int) -> Void
        typealias NumArgsFunc = @convention(c) (AnyObject, Selector) -> Int
        typealias ArgTypeFunc = @convention(c) (AnyObject, Selector, Int) -> UnsafePointer<CChar>

        let setArg = unsafeBitCast(setArgImp, to: SetArgFunc.self)
        let numArgs = unsafeBitCast(numArgsImp, to: NumArgsFunc.self)(sig, numArgsSel)
        let getArgType = unsafeBitCast(argTypeImp, to: ArgTypeFunc.self)

        var retainedObjects: [Unmanaged<AnyObject>] = []
        defer {
            for obj in retainedObjects {
                obj.release()
            }
        }

        for i in 0..<(numArgs - 2) {
            guard i < args.count else { break }
            let argIndex = i + 2
            let typeEncoding = String(cString: getArgType(sig, argTypeSel, argIndex))
            let arg = args[i]

            if typeEncoding.hasPrefix("q") || typeEncoding.hasPrefix("l") {
                var val: Int64 = (arg as? Int64) ?? (arg as? Int).map(Int64.init) ?? 0
                setArg(invocation, setArgSel, &val, argIndex)
            } else if typeEncoding.hasPrefix("i") || typeEncoding.hasPrefix("s") {
                var val: Int32 = (arg as? Int32) ?? (arg as? Int).map(Int32.init) ?? 0
                setArg(invocation, setArgSel, &val, argIndex)
            } else if typeEncoding.hasPrefix("d") {
                var val: Double = (arg as? Double) ?? (arg as? Float).map(Double.init) ?? 0.0
                setArg(invocation, setArgSel, &val, argIndex)
            } else if typeEncoding.hasPrefix("f") {
                var val: Float = (arg as? Float) ?? (arg as? Double).map(Float.init) ?? 0.0
                setArg(invocation, setArgSel, &val, argIndex)
            } else if typeEncoding.hasPrefix("B") || typeEncoding.hasPrefix("c") {
                var val: Bool = (arg as? Bool) ?? false
                setArg(invocation, setArgSel, &val, argIndex)
            } else if typeEncoding.hasPrefix("@") {
                let unmanaged = Unmanaged.passRetained(arg as AnyObject)
                retainedObjects.append(unmanaged)
                var rawPtr = unmanaged.toOpaque()
                withUnsafePointer(to: &rawPtr) { ptr in
                    setArg(invocation, setArgSel, ptr, argIndex)
                }
            }
        }

        // 5. Invoke
        if let imp = class_getMethodImplementation(type(of: invocation), invokeSel) {
            typealias InvokeFunc = @convention(c) (AnyObject, Selector) -> Void
            unsafeBitCast(imp, to: InvokeFunc.self)(invocation, invokeSel)
        }

        // 6. Extract return value
        guard let retLenImp = class_getMethodImplementation(type(of: sig), retLenSel) else {
            return nil
        }
        typealias RetLenFunc = @convention(c) (AnyObject, Selector) -> Int
        let retLen = unsafeBitCast(retLenImp, to: RetLenFunc.self)(sig, retLenSel)
        guard retLen > 0 else { return nil }

        guard let retTypeImp = class_getMethodImplementation(type(of: sig), retTypeSel),
              let getRetImp = class_getMethodImplementation(type(of: invocation), getRetSel) else {
            return nil
        }
        typealias RetTypeFunc = @convention(c) (AnyObject, Selector) -> UnsafePointer<CChar>
        typealias GetRetFunc = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Void

        let retTypeStr = String(cString: unsafeBitCast(retTypeImp, to: RetTypeFunc.self)(sig, retTypeSel))
        let getRet = unsafeBitCast(getRetImp, to: GetRetFunc.self)

        switch retTypeStr {
        case "q", "l":
            var val: Int64 = 0
            getRet(invocation, getRetSel, &val)
            return Int(val)
        case "i", "s":
            var val: Int32 = 0
            getRet(invocation, getRetSel, &val)
            return Int(val)
        case "d":
            var val: Double = 0
            getRet(invocation, getRetSel, &val)
            return val
        case "f":
            var val: Float = 0
            getRet(invocation, getRetSel, &val)
            return Double(val)
        case "B", "c":
            var val: Bool = false
            getRet(invocation, getRetSel, &val)
            return val
        case "@":
            var unmanagedObj: Unmanaged<AnyObject>?
            withUnsafeMutablePointer(to: &unmanagedObj) { ptr in
                getRet(invocation, getRetSel, ptr)
            }
            return unmanagedObj?.takeUnretainedValue()
        default:
            return nil
        }
    }
}
