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

    init(pluginName: String, className: String, methodName: String) {
        self.pluginName = pluginName
        self.className = className
        self.methodName = methodName
        self.methodStringName = GodotStringName.cached(methodName)
    }
}

/// Information needed to dispatch an extension class instance.
private final class ClassBindingData {
    let pluginName: String
    let className: String
    let classStringName: GodotStringName
    let parentStringName: GodotStringName
    var godotObject: GDExtensionObjectPtr?

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
            return godotObj
        }

        creationInfo.free_instance_func = { userdata, instancePtr in
            // Instance cleanup
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
        let methodNames = GodotPluginRegistry.shared.getMethods(for: pluginName)
        for methodName in methodNames {
            registerMethod(className: className, pluginName: pluginName, methodName: methodName)
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

    /// Registers a method for a plugin class in ClassDB.
    private func registerMethod(className: String, pluginName: String, methodName: String) {
        guard let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil,
              let registerMethodFunc = gi.classdb_register_extension_class_method else {
            return
        }

        let methodData = MethodBindingData(pluginName: pluginName, className: className, methodName: methodName)
        let methodDataPtr = Unmanaged.passRetained(methodData).toOpaque()
        retainedBindings.append(methodDataPtr)

        let emptyStringName = GodotStringName.cached("")
        let emptyString = GodotString.cached("")

        emptyStringName.withUnsafeMutableRawPointer { emptyNamePtr in
            emptyString.withUnsafeMutableRawPointer { emptyStrPtr in
                methodData.methodStringName.withUnsafeMutableRawPointer { methodNamePtr in
                    GodotStringName.cached(className).withUnsafeRawPointer { classNamePtr in
                        var returnProp = GDExtensionPropertyInfo(
                            type: GDEXTENSION_VARIANT_TYPE_NIL,
                            name: emptyNamePtr,
                            class_name: emptyNamePtr,
                            hint: 0,
                            hint_string: emptyStrPtr,
                            usage: 6 | (1 << 17) // PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_NIL_IS_VARIANT
                        )

                        withUnsafeMutablePointer(to: &returnProp) { returnPropPtr in
                            var methodInfo = GDExtensionClassMethodInfo()
                            methodInfo.name = methodNamePtr
                            methodInfo.method_userdata = methodDataPtr
                            methodInfo.method_flags = 1 // GDEXTENSION_METHOD_FLAGS_DEFAULT
                            methodInfo.has_return_value = 1
                            methodInfo.return_value_info = returnPropPtr
                            methodInfo.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE
                            methodInfo.argument_count = 0
                            methodInfo.arguments_info = nil
                            methodInfo.arguments_metadata = nil
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

                                let result = GodotPluginRegistry.shared.callMethod(
                                    pluginName: binding.pluginName,
                                    methodName: binding.methodName,
                                    args: []
                                )

                                if let returnPtr {
                                    GodotVariant.writeVariant(result, to: returnPtr)
                                }
                            }

                            registerMethodFunc(gi.library, classNamePtr, &methodInfo)
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
        engineVariant.withUnsafeMutableRawPointer { engineVarPtr in
            var objPtrCopy = engineObj
            variantFromObj(engineVarPtr, &objPtrCopy)
        }

        var nameVariant = GodotVariantBuffer()
        nameVariant.withUnsafeMutableRawPointer { nameVarPtr in
            GodotVariant.writeVariant(name, to: nameVarPtr)
        }

        var instanceVariant = GodotVariantBuffer()
        instanceVariant.withUnsafeMutableRawPointer { instanceVarPtr in
            var objPtrCopy = object
            variantFromObj(instanceVarPtr, &objPtrCopy)
        }

        nameVariant.withUnsafeRawPointer { namePtr in
            instanceVariant.withUnsafeRawPointer { instPtr in
                var args: [GDExtensionConstVariantPtr?] = [namePtr, instPtr]
                var retVariant = GodotVariantBuffer()
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
                  let godotObj = classData.godotObject,
                  let gi = GodotInterface.shared.isInitialized ? GodotInterface.shared : nil,
                  let variantCall = gi.variant_call,
                  let variantFromObj = gi.variantFromObject else {
                return
            }

            var objVariant = GodotVariantBuffer()
            objVariant.withUnsafeMutableRawPointer { objVarPtr in
                var copy = godotObj
                variantFromObj(objVarPtr, &copy)
            }

            var signalNameVariant = GodotVariantBuffer()
            signalNameVariant.withUnsafeMutableRawPointer { sPtr in
                GodotVariant.writeVariant(signalName, to: sPtr)
            }

            var argVariants = [GodotVariantBuffer](repeating: GodotVariantBuffer(), count: args.count)
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

                    var retVariant = GodotVariantBuffer()
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
