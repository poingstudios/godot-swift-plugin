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

/// Information needed to dispatch a method invocation from Godot.
private final class MethodBindingData {
    let pluginName: String
    let className: String
    let methodName: String
    let methodStringName: GodotStringName
    let metadata: GodotMethodMetadata

    init(pluginName: String, className: String, metadata: GodotMethodMetadata) {
        self.pluginName = pluginName
        self.className = className
        self.methodName = metadata.canonicalName
        self.methodStringName = GodotStringName.cached(metadata.canonicalName)
        self.metadata = metadata
    }
}

/// Information needed to dispatch an extension class instance.
private final class ClassBindingData {
    let pluginName: String
    let className: String
    let classStringName: GodotStringName
    let parentStringName: GodotStringName
    var godotObject: GDExtensionObjectPtr?
    var instances: [GDExtensionObjectPtr] = []

    init(pluginName: String, className: String) {
        self.pluginName = pluginName
        self.className = className
        self.classStringName = GodotStringName.cached(className)
        self.parentStringName = GodotStringName.cached("Object")
    }
}

/// Central service managing ClassDB registration and Godot Object instance lifecycles.
public final class GodotClassDB: @unchecked Sendable {
    public static let shared = GodotClassDB()

    private let lock = NSLock()
    private var classBindings: [String: ClassBindingData] = [:]
    private var retainedBindings: [UnsafeMutableRawPointer] = []

    public init() {}

    /// Checks whether a plugin's class is already registered in ClassDB.
    public func isRegistered(_ plugin: GodotPlugin) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let className = type(of: plugin).pluginClassName
        return classBindings[className] != nil
    }

    /// Registers a GodotPlugin into ClassDB and binds it to an Engine singleton.
    public func registerPlugin(_ plugin: GodotPlugin) {
        guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil else {
            return
        }

        let pluginType = type(of: plugin)
        let pluginName = pluginType.pluginName
        let className = pluginType.pluginClassName

        lock.lock()
        if classBindings[className] != nil {
            lock.unlock()
            return
        }
        let classData = ClassBindingData(pluginName: pluginName, className: className)
        classBindings[className] = classData
        lock.unlock()

        let classDataPtr = Unmanaged.passRetained(classData).toOpaque()
        retainedBindings.append(classDataPtr)

        // 1. Register Extension Class with ClassDB
        var creationInfo = GDExtensionClassCreationInfo2()
        creationInfo.is_virtual = 0
        creationInfo.is_abstract = 0
        creationInfo.is_exposed = 1
        creationInfo.class_userdata = classDataPtr

        creationInfo.create_instance_func = { userdata in
            guard let userdata,
                  let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil else {
                return nil
            }
            let data = Unmanaged<ClassBindingData>.fromOpaque(userdata).takeUnretainedValue()

            // Construct underlying Godot Object
            let godotObj: GDExtensionObjectPtr?
            if let construct3 = gi.classdb_construct_object3 {
                godotObj = data.parentStringName.withUnsafeRawPointer { construct3($0) }
            } else if let construct = gi.classdb_construct_object {
                godotObj = data.parentStringName.withUnsafeRawPointer { construct($0) }
            } else {
                godotObj = nil
            }

            guard let godotObj else { return nil }

            let swiftInstancePtr = UnsafeMutableRawPointer(userdata)
            data.classStringName.withUnsafeRawPointer { classNamePtr in
                gi.object_set_instance?(godotObj, classNamePtr, swiftInstancePtr)
            }
            data.instances.append(godotObj)
            return godotObj
        }

        creationInfo.free_instance_func = { userdata, instancePtr in
            guard let userdata, let instancePtr else { return }
            let data = Unmanaged<ClassBindingData>.fromOpaque(userdata).takeUnretainedValue()
            data.instances.removeAll { $0 == instancePtr }
        }

        classData.classStringName.withUnsafeRawPointer { classNamePtr in
            classData.parentStringName.withUnsafeRawPointer { parentNamePtr in
                if let register2 = gi.classdb_register_extension_class2 {
                    register2(gi.library, classNamePtr, parentNamePtr, &creationInfo)
                } else if let registerLegacy = gi.classdb_register_extension_class {
                    var legacyInfo = GDExtensionClassCreationInfo()
                    legacyInfo.is_virtual = creationInfo.is_virtual
                    legacyInfo.is_abstract = creationInfo.is_abstract
                    legacyInfo.create_instance_func = creationInfo.create_instance_func
                    legacyInfo.free_instance_func = creationInfo.free_instance_func
                    legacyInfo.class_userdata = creationInfo.class_userdata
                    registerLegacy(gi.library, classNamePtr, parentNamePtr, &legacyInfo)
                }
            }
        }

        // 2. Register Methods
        let canonicalMetadata = GodotPluginRegistry.shared.getCanonicalMethodMetadata(for: pluginName)
        if !canonicalMetadata.isEmpty {
            for meta in canonicalMetadata {
                registerMethod(className: className, pluginName: pluginName, metadata: meta)
            }
        } else {
            let methodNames = GodotPluginRegistry.shared.getMethods(for: pluginName)
            for methodName in methodNames {
                let argCount = GodotPluginRegistry.shared.getArgumentCount(for: pluginName, methodName: methodName)
                registerMethod(
                    className: className,
                    pluginName: pluginName,
                    metadata: GodotMethodMetadata(
                        canonicalName: methodName,
                        selector: NSSelectorFromString(methodName),
                        argumentNames: (0..<argCount).map { "arg\($0)" },
                        argumentTypes: [GDExtensionVariantType](repeating: GDEXTENSION_VARIANT_TYPE_NIL, count: argCount),
                        returnType: GDEXTENSION_VARIANT_TYPE_NIL
                    )
                )
            }
        }

        // 3. Register Signals
        let signalNames = GodotPluginRegistry.shared.getSignals(for: pluginName)
        for signalName in signalNames {
            registerSignal(className: className, signalName: signalName)
        }

        // 4. Construct Object Instance and Register with Engine Singleton
        let instanceObj: GDExtensionObjectPtr?
        if let construct3 = gi.classdb_construct_object3 {
            instanceObj = classData.parentStringName.withUnsafeRawPointer { construct3($0) }
        } else if let construct = gi.classdb_construct_object {
            instanceObj = classData.parentStringName.withUnsafeRawPointer { construct($0) }
        } else {
            instanceObj = nil
        }

        if let instanceObj {
            classData.godotObject = instanceObj
            classData.classStringName.withUnsafeRawPointer { classNamePtr in
                gi.object_set_instance?(instanceObj, classNamePtr, classDataPtr)
            }
            registerSingleton(name: pluginName, object: instanceObj)
        }
    }

    /// Helper safely borrowing string name pointers for ClassDB argument registration.
    private func withArgNamePointers<R>(
        stringNames: [GodotStringName],
        index: Int = 0,
        ptrs: [GDExtensionStringNamePtr] = [],
        _ body: ([GDExtensionStringNamePtr]) throws -> R
    ) rethrows -> R {
        if index >= stringNames.count {
            return try body(ptrs)
        }
        return try stringNames[index].withUnsafeMutableRawPointer { ptr in
            var next = ptrs
            next.append(ptr)
            return try withArgNamePointers(stringNames: stringNames, index: index + 1, ptrs: next, body)
        }
    }

    /// Registers a method for a plugin class in ClassDB.
    private func registerMethod(
        className: String,
        pluginName: String,
        metadata: GodotMethodMetadata
    ) {
        guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil,
              let registerMethodFunc = gi.classdb_register_extension_class_method else {
            return
        }

        let methodData = MethodBindingData(pluginName: pluginName, className: className, metadata: metadata)
        let methodDataPtr = Unmanaged.passRetained(methodData).toOpaque()
        retainedBindings.append(methodDataPtr)

        let emptyStringName = GodotStringName.cached("")
        let emptyString = GodotString.cached("")

        emptyStringName.withUnsafeMutableRawPointer { emptyNamePtr in
            emptyString.withUnsafeMutableRawPointer { emptyStrPtr in
                methodData.methodStringName.withUnsafeMutableRawPointer { methodNamePtr in
                    GodotStringName.cached(className).withUnsafeRawPointer { classNamePtr in
                        let argCount = metadata.argumentNames.count
                        let argNameObjects = metadata.argumentNames.map { GodotStringName.cached($0) }

                        withArgNamePointers(stringNames: argNameObjects) { argNamePtrs in
                            var argProps: [GDExtensionPropertyInfo] = []
                            var argMetadata: [GDExtensionClassMethodArgumentMetadata] = []
                            argProps.reserveCapacity(argCount)
                            argMetadata.reserveCapacity(argCount)

                            for i in 0..<argCount {
                                let argType = metadata.argumentTypes[i]
                                argProps.append(GDExtensionPropertyInfo(
                                    type: argType,
                                    name: argNamePtrs[i],
                                    class_name: emptyNamePtr,
                                    hint: 0,
                                    hint_string: emptyStrPtr,
                                    usage: argType == GDEXTENSION_VARIANT_TYPE_NIL ? (6 | (1 << 17)) : 6
                                ))
                                argMetadata.append(GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE)
                            }

                            argProps.withUnsafeMutableBufferPointer { argPropsBuf in
                                argMetadata.withUnsafeMutableBufferPointer { argMetaBuf in
                                    let hasReturn = metadata.returnType != nil
                                    let retType = metadata.returnType ?? GDEXTENSION_VARIANT_TYPE_NIL

                                    var returnProp = GDExtensionPropertyInfo(
                                        type: retType,
                                        name: emptyNamePtr,
                                        class_name: emptyNamePtr,
                                        hint: 0,
                                        hint_string: emptyStrPtr,
                                        usage: retType == GDEXTENSION_VARIANT_TYPE_NIL ? (6 | (1 << 17)) : 6
                                    )

                                    withUnsafeMutablePointer(to: &returnProp) { returnPropPtr in
                                        var methodInfo = GDExtensionClassMethodInfo()
                                        methodInfo.name = methodNamePtr
                                        methodInfo.method_userdata = methodDataPtr
                                        methodInfo.method_flags = 1 // GDEXTENSION_METHOD_FLAGS_DEFAULT
                                        methodInfo.has_return_value = hasReturn ? 1 : 0
                                        methodInfo.return_value_info = hasReturn ? returnPropPtr : nil
                                        methodInfo.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE
                                        methodInfo.argument_count = UInt32(argCount)
                                        methodInfo.arguments_info = argCount > 0 ? argPropsBuf.baseAddress : nil
                                        methodInfo.arguments_metadata = argCount > 0 ? argMetaBuf.baseAddress : nil
                                        methodInfo.default_argument_count = 0
                                        methodInfo.default_arguments = nil

                                        methodInfo.call_func = { methodUserdata, instancePtr, args, argCount, returnPtr, errorPtr in
                                            guard let methodUserdata else { return }
                                            let binding = Unmanaged<MethodBindingData>.fromOpaque(methodUserdata).takeUnretainedValue()

                                            let swiftArgs = GodotVariant.toSwiftArray(args: args, count: Int(argCount))
                                            let result = GodotPluginRegistry.shared.callMethod(
                                                pluginName: binding.pluginName,
                                                methodName: binding.methodName,
                                                args: swiftArgs
                                            )

                                            if let returnPtr {
                                                GodotVariant.writeVariant(result, to: returnPtr)
                                            }
                                            errorPtr?.pointee.error = GDEXTENSION_CALL_OK
                                        }

                                        methodInfo.ptrcall_func = { methodUserdata, instancePtr, args, returnPtr in
                                            guard let methodUserdata else { return }
                                            let binding = Unmanaged<MethodBindingData>.fromOpaque(methodUserdata).takeUnretainedValue()
                                            guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil else { return }

                                            let expectedArgTypes = binding.metadata.argumentTypes
                                            var swiftArgs: [Any] = []
                                            swiftArgs.reserveCapacity(expectedArgTypes.count)

                                            for i in 0..<expectedArgTypes.count {
                                                guard let argPtr = args?[i] else {
                                                    swiftArgs.append(())
                                                    continue
                                                }

                                                switch expectedArgTypes[i] {
                                                case GDEXTENSION_VARIANT_TYPE_BOOL:
                                                    swiftArgs.append(argPtr.assumingMemoryBound(to: UInt8.self).pointee != 0)
                                                case GDEXTENSION_VARIANT_TYPE_INT:
                                                    swiftArgs.append(Int(argPtr.assumingMemoryBound(to: Int64.self).pointee))
                                                case GDEXTENSION_VARIANT_TYPE_FLOAT:
                                                    swiftArgs.append(argPtr.assumingMemoryBound(to: Double.self).pointee)
                                                case GDEXTENSION_VARIANT_TYPE_STRING:
                                                    if let toUtf8 = gi.string_to_utf8_chars {
                                                        let len = toUtf8(UnsafeMutableRawPointer(mutating: argPtr), nil, 0)
                                                        var buffer = [CChar](repeating: 0, count: Int(len) + 1)
                                                        _ = toUtf8(UnsafeMutableRawPointer(mutating: argPtr), &buffer, len)
                                                        swiftArgs.append(String(cString: buffer))
                                                    } else {
                                                        swiftArgs.append("")
                                                    }
                                                default:
                                                    if let val = GodotVariant.toSwift(argPtr) {
                                                        swiftArgs.append(val)
                                                    } else {
                                                        swiftArgs.append(())
                                                    }
                                                }
                                            }

                                            let result = GodotPluginRegistry.shared.callMethod(
                                                pluginName: binding.pluginName,
                                                methodName: binding.methodName,
                                                args: swiftArgs
                                            )

                                            if let returnPtr {
                                                if let retType = binding.metadata.returnType {
                                                    switch retType {
                                                    case GDEXTENSION_VARIANT_TYPE_BOOL:
                                                        returnPtr.assumingMemoryBound(to: UInt8.self).pointee = ((result as? Bool) ?? false) ? 1 : 0
                                                    case GDEXTENSION_VARIANT_TYPE_INT:
                                                        returnPtr.assumingMemoryBound(to: Int64.self).pointee = Int64((result as? Int) ?? 0)
                                                    case GDEXTENSION_VARIANT_TYPE_FLOAT:
                                                        if let doubleVal = result as? Double {
                                                            returnPtr.assumingMemoryBound(to: Double.self).pointee = doubleVal
                                                        } else if let floatVal = result as? Float {
                                                            returnPtr.assumingMemoryBound(to: Double.self).pointee = Double(floatVal)
                                                        } else {
                                                            returnPtr.assumingMemoryBound(to: Double.self).pointee = 0.0
                                                        }
                                                    case GDEXTENSION_VARIANT_TYPE_STRING:
                                                        if let strVal = result as? String, let newWithUtf8 = gi.string_new_with_utf8_chars {
                                                            strVal.withCString { cstr in
                                                                newWithUtf8(returnPtr, cstr)
                                                            }
                                                        }
                                                    default:
                                                        GodotVariant.writeVariant(result, to: returnPtr)
                                                    }
                                                } else {
                                                    // Void return - nothing to write
                                                }
                                            }
                                        }

                                        registerMethodFunc(gi.library, classNamePtr, &methodInfo)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Registers a signal for a plugin class in ClassDB.
    private func registerSignal(className: String, signalName: String) {
        guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil,
              let registerSignalFunc = gi.classdb_register_extension_class_signal else {
            return
        }

        GodotStringName.cached(className).withUnsafeRawPointer { classNamePtr in
            GodotStringName.cached(signalName).withUnsafeRawPointer { signalNamePtr in
                registerSignalFunc(gi.library, classNamePtr, signalNamePtr, nil, 0)
            }
        }
    }

    /// Registers the object as an Engine singleton so GDScript can call Engine.get_singleton(name).
    private func registerSingleton(name: String, object: GDExtensionObjectPtr) {
        guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil,
              let getGlobalSingleton = gi.global_get_singleton,
              let variantCall = gi.variant_call,
              let variantFromObj = gi.variantFromObject else {
            return
        }

        let engineObj = GodotStringName.cached("Engine").withUnsafeRawPointer { engineNamePtr in
            getGlobalSingleton(engineNamePtr)
        }
        guard let engineObj else { return }

        var engineVariant = GodotVariantBuffer()
        defer { engineVariant.destroy(using: gi) }
        engineVariant.withUnsafeMutableRawPointer { engineVarPtr in
            var objPtrCopy = engineObj
            variantFromObj(engineVarPtr, &objPtrCopy)
        }

        var nameVariant = GodotVariantBuffer()
        defer { nameVariant.destroy(using: gi) }
        nameVariant.withUnsafeMutableRawPointer { nameVarPtr in
            GodotVariant.writeVariant(name, to: nameVarPtr)
        }

        var instanceVariant = GodotVariantBuffer()
        defer { instanceVariant.destroy(using: gi) }
        instanceVariant.withUnsafeMutableRawPointer { instanceVarPtr in
            var objPtrCopy = object
            variantFromObj(instanceVarPtr, &objPtrCopy)
        }

        nameVariant.withUnsafeRawPointer { namePtr in
            instanceVariant.withUnsafeRawPointer { instPtr in
                var args: [GDExtensionConstVariantPtr?] = [namePtr, instPtr]
                var retVariant = GodotVariantBuffer()
                defer { retVariant.destroy(using: gi) }
                var error = GDExtensionCallError()

                engineVariant.withUnsafeMutableRawPointer { engineVarPtr in
                    retVariant.withUnsafeMutableRawPointer { retVarPtr in
                        GodotStringName.cached("register_singleton").withUnsafeRawPointer { methodPtr in
                            args.withUnsafeMutableBufferPointer { argsBuf in
                                variantCall(
                                    engineVarPtr,
                                    methodPtr,
                                    argsBuf.baseAddress,
                                    2,
                                    retVarPtr,
                                    &error
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /// Emits a signal on the plugin's registered Godot Object.
    public func emitSignal(pluginName: String, signalName: String, args: [Any] = []) {
        let emitBlock = { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let classData = self.classBindings.values.first { $0.pluginName == pluginName } ?? self.classBindings[pluginName]
            self.lock.unlock()

            guard let classData,
                  let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil,
                  let variantCall = gi.variant_call,
                  let variantFromObj = gi.variantFromObject else {
                return
            }

            var targetObjects: [GDExtensionObjectPtr] = []
            if let single = classData.godotObject {
                targetObjects.append(single)
            }
            for inst in classData.instances {
                if inst != classData.godotObject {
                    targetObjects.append(inst)
                }
            }

            guard !targetObjects.isEmpty else { return }

            var signalNameVariant = GodotVariantBuffer()
            defer { signalNameVariant.destroy(using: gi) }
            signalNameVariant.withUnsafeMutableRawPointer { sPtr in
                GodotVariant.writeVariant(signalName, to: sPtr)
            }

            var argVariants = [GodotVariantBuffer](repeating: GodotVariantBuffer(), count: args.count)
            defer {
                for i in argVariants.indices {
                    argVariants[i].destroy(using: gi)
                }
            }
            argVariants.withUnsafeMutableBufferPointer { argBuf in
                for i in 0..<args.count {
                    let destPtr = UnsafeMutableRawPointer(argBuf.baseAddress!.advanced(by: i))
                    GodotVariant.writeVariant(args[i], to: destPtr)
                }
            }

            signalNameVariant.withUnsafeRawPointer { sPtr in
                argVariants.withUnsafeBufferPointer { argBuf in
                    var rawArgPointers: [GDExtensionConstVariantPtr?] = []
                    rawArgPointers.reserveCapacity(args.count + 1)
                    rawArgPointers.append(sPtr)
                    for i in 0..<args.count {
                        let aPtr = UnsafeRawPointer(argBuf.baseAddress!.advanced(by: i))
                        rawArgPointers.append(aPtr)
                    }

                    for targetObj in targetObjects {
                        var objVariant = GodotVariantBuffer()
                        defer { objVariant.destroy(using: gi) }
                        objVariant.withUnsafeMutableRawPointer { objVarPtr in
                            var copy = targetObj
                            variantFromObj(objVarPtr, &copy)
                        }

                        var retVariant = GodotVariantBuffer()
                        defer { retVariant.destroy(using: gi) }
                        var error = GDExtensionCallError()

                        objVariant.withUnsafeMutableRawPointer { objVarPtr in
                            retVariant.withUnsafeMutableRawPointer { retVarPtr in
                                GodotStringName.cached("emit_signal").withUnsafeRawPointer { methodPtr in
                                    rawArgPointers.withUnsafeMutableBufferPointer { rawArgsBuf in
                                        variantCall(
                                            objVarPtr,
                                            methodPtr,
                                            rawArgsBuf.baseAddress,
                                            GDExtensionInt(rawArgsBuf.count),
                                            retVarPtr,
                                            &error
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if Thread.isMainThread {
            emitBlock()
        } else {
            DispatchQueue.main.async(execute: emitBlock)
        }
    }

    /// Cleans up registered singletons and bindings.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        if let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil {
            for (_, binding) in classBindings {
                if let obj = binding.godotObject {
                    gi.object_destroy?(obj)
                }
            }
        }

        classBindings.removeAll()
        for ptr in retainedBindings {
            Unmanaged<AnyObject>.fromOpaque(ptr).release()
        }
        retainedBindings.removeAll()
    }
}
