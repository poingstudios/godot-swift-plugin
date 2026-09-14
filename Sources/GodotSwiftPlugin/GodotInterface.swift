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

/// Central wrapper managing all GDExtension function pointers resolved at runtime.
public final class GodotInterface: @unchecked Sendable {
    public static let shared = GodotInterface()

    public private(set) var isInitialized: Bool = false
    public private(set) var library: GDExtensionClassLibraryPtr?

    // Core Memory & Diagnostics
    public var mem_alloc: GDExtensionInterfaceMemAlloc?
    public var mem_free: GDExtensionInterfaceMemFree?
    public var print_error: GDExtensionInterfacePrintError?
    public var print_warning: GDExtensionInterfacePrintWarning?

    // String & StringName
    public var string_new_with_utf8_chars: GDExtensionInterfaceStringNewWithUtf8Chars?
    public var string_to_utf8_chars: GDExtensionInterfaceStringToUtf8Chars?
    public var string_name_new_with_utf8_chars: GDExtensionInterfaceStringNameNewWithUtf8Chars?
    public var stringDestructor: GDExtensionPtrDestructor?
    public var stringNameDestructor: GDExtensionPtrDestructor?

    // Variant Operations
    public var variant_new_copy: GDExtensionInterfaceVariantNewCopy?
    public var variant_new_nil: GDExtensionInterfaceVariantNewNil?
    public var variant_destroy: GDExtensionInterfaceVariantDestroy?
    public var variant_get_type: GDExtensionInterfaceVariantGetType?
    public var variant_call: GDExtensionInterfaceVariantCall?
    public var variant_construct: GDExtensionInterfaceVariantConstruct?
    public var variant_set_keyed: GDExtensionInterfaceVariantSetKeyed?
    public var variant_get_keyed: GDExtensionInterfaceVariantGetKeyed?
    public var variant_get_indexed: GDExtensionInterfaceVariantGetIndexed?
    public var variant_get_ptr_destructor: GDExtensionInterfaceVariantGetPtrDestructor?
    public var get_variant_from_type_constructor: GDExtensionInterfaceGetVariantFromTypeConstructor?
    public var get_variant_to_type_constructor: GDExtensionInterfaceGetVariantToTypeConstructor?

    // Type Constructors (From Type to Variant)
    public var variantFromBool: GDExtensionVariantFromTypeConstructorFunc?
    public var variantFromInt: GDExtensionVariantFromTypeConstructorFunc?
    public var variantFromFloat: GDExtensionVariantFromTypeConstructorFunc?
    public var variantFromString: GDExtensionVariantFromTypeConstructorFunc?
    public var variantFromStringName: GDExtensionVariantFromTypeConstructorFunc?
    public var variantFromObject: GDExtensionVariantFromTypeConstructorFunc?

    // Type Constructors (From Variant to Type)
    public var boolFromVariant: GDExtensionTypeFromVariantConstructorFunc?
    public var intFromVariant: GDExtensionTypeFromVariantConstructorFunc?
    public var floatFromVariant: GDExtensionTypeFromVariantConstructorFunc?
    public var stringFromVariant: GDExtensionTypeFromVariantConstructorFunc?
    public var stringNameFromVariant: GDExtensionTypeFromVariantConstructorFunc?
    public var objectFromVariant: GDExtensionTypeFromVariantConstructorFunc?

    // ClassDB & Object Model
    public var classdb_register_extension_class: GDExtensionInterfaceClassdbRegisterExtensionClass?
    public var classdb_register_extension_class2: GDExtensionInterfaceClassdbRegisterExtensionClass2?
    public var classdb_register_extension_class_method: GDExtensionInterfaceClassdbRegisterExtensionClassMethod?
    public var classdb_register_extension_class_signal: GDExtensionInterfaceClassdbRegisterExtensionClassSignal?
    public var classdb_construct_object: GDExtensionInterfaceClassdbConstructObject?
    public var classdb_construct_object3: GDExtensionInterfaceClassdbConstructObject3?
    public var object_destroy: GDExtensionInterfaceObjectDestroy?
    public var object_set_instance: GDExtensionInterfaceObjectSetInstance?
    public var global_get_singleton: GDExtensionInterfaceGlobalGetSingleton?
    public var object_method_bind_call: GDExtensionInterfaceObjectMethodBindCall?

    public init() {}

    /// Loads and caches all GDExtension function pointers via `GDExtensionInterfaceGetProcAddress`.
    public func load(
        getProcAddress: GDExtensionInterfaceGetProcAddress,
        library: GDExtensionClassLibraryPtr?
    ) {
        self.library = library

        func resolve<T>(_ name: String, as type: T.Type) -> T? {
            guard let ptr = getProcAddress(name) else { return nil }
            return unsafeBitCast(ptr, to: type)
        }

        // Diagnostics
        mem_alloc = resolve("mem_alloc", as: GDExtensionInterfaceMemAlloc.self)
        mem_free = resolve("mem_free", as: GDExtensionInterfaceMemFree.self)
        print_error = resolve("print_error", as: GDExtensionInterfacePrintError.self)
        print_warning = resolve("print_warning", as: GDExtensionInterfacePrintWarning.self)

        // Strings
        string_new_with_utf8_chars = resolve("string_new_with_utf8_chars", as: GDExtensionInterfaceStringNewWithUtf8Chars.self)
        string_to_utf8_chars = resolve("string_to_utf8_chars", as: GDExtensionInterfaceStringToUtf8Chars.self)
        string_name_new_with_utf8_chars = resolve("string_name_new_with_utf8_chars", as: GDExtensionInterfaceStringNameNewWithUtf8Chars.self)

        // Variants
        variant_new_copy = resolve("variant_new_copy", as: GDExtensionInterfaceVariantNewCopy.self)
        variant_new_nil = resolve("variant_new_nil", as: GDExtensionInterfaceVariantNewNil.self)
        variant_destroy = resolve("variant_destroy", as: GDExtensionInterfaceVariantDestroy.self)
        variant_get_type = resolve("variant_get_type", as: GDExtensionInterfaceVariantGetType.self)
        variant_call = resolve("variant_call", as: GDExtensionInterfaceVariantCall.self)
        variant_construct = resolve("variant_construct", as: GDExtensionInterfaceVariantConstruct.self)
        variant_set_keyed = resolve("variant_set_keyed", as: GDExtensionInterfaceVariantSetKeyed.self)
        variant_get_keyed = resolve("variant_get_keyed", as: GDExtensionInterfaceVariantGetKeyed.self)
        variant_get_indexed = resolve("variant_get_indexed", as: GDExtensionInterfaceVariantGetIndexed.self)
        variant_get_ptr_destructor = resolve("variant_get_ptr_destructor", as: GDExtensionInterfaceVariantGetPtrDestructor.self)
        get_variant_from_type_constructor = resolve("get_variant_from_type_constructor", as: GDExtensionInterfaceGetVariantFromTypeConstructor.self)
        get_variant_to_type_constructor = resolve("get_variant_to_type_constructor", as: GDExtensionInterfaceGetVariantToTypeConstructor.self)

        // Resolve built-in destructors
        if let getDestructor = variant_get_ptr_destructor {
            stringDestructor = getDestructor(GDEXTENSION_VARIANT_TYPE_STRING)
            stringNameDestructor = getDestructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)
        }

        // Resolve built-in constructors
        if let fromType = get_variant_from_type_constructor {
            variantFromBool = fromType(GDEXTENSION_VARIANT_TYPE_BOOL)
            variantFromInt = fromType(GDEXTENSION_VARIANT_TYPE_INT)
            variantFromFloat = fromType(GDEXTENSION_VARIANT_TYPE_FLOAT)
            variantFromString = fromType(GDEXTENSION_VARIANT_TYPE_STRING)
            variantFromStringName = fromType(GDEXTENSION_VARIANT_TYPE_STRING_NAME)
            variantFromObject = fromType(GDEXTENSION_VARIANT_TYPE_OBJECT)
        }

        if let toType = get_variant_to_type_constructor {
            boolFromVariant = toType(GDEXTENSION_VARIANT_TYPE_BOOL)
            intFromVariant = toType(GDEXTENSION_VARIANT_TYPE_INT)
            floatFromVariant = toType(GDEXTENSION_VARIANT_TYPE_FLOAT)
            stringFromVariant = toType(GDEXTENSION_VARIANT_TYPE_STRING)
            stringNameFromVariant = toType(GDEXTENSION_VARIANT_TYPE_STRING_NAME)
            objectFromVariant = toType(GDEXTENSION_VARIANT_TYPE_OBJECT)
        }

        // ClassDB & Object
        classdb_register_extension_class = resolve("classdb_register_extension_class", as: GDExtensionInterfaceClassdbRegisterExtensionClass.self)
        classdb_register_extension_class2 = resolve("classdb_register_extension_class2", as: GDExtensionInterfaceClassdbRegisterExtensionClass2.self)
        classdb_register_extension_class_method = resolve("classdb_register_extension_class_method", as: GDExtensionInterfaceClassdbRegisterExtensionClassMethod.self)
        classdb_register_extension_class_signal = resolve("classdb_register_extension_class_signal", as: GDExtensionInterfaceClassdbRegisterExtensionClassSignal.self)
        classdb_construct_object = resolve("classdb_construct_object", as: GDExtensionInterfaceClassdbConstructObject.self)
        classdb_construct_object3 = resolve("classdb_construct_object3", as: GDExtensionInterfaceClassdbConstructObject3.self)
        object_destroy = resolve("object_destroy", as: GDExtensionInterfaceObjectDestroy.self)
        object_set_instance = resolve("object_set_instance", as: GDExtensionInterfaceObjectSetInstance.self)
        global_get_singleton = resolve("global_get_singleton", as: GDExtensionInterfaceGlobalGetSingleton.self)
        object_method_bind_call = resolve("object_method_bind_call", as: GDExtensionInterfaceObjectMethodBindCall.self)

        isInitialized = true
    }

    /// Resets all function pointers.
    public func reset() {
        library = nil
        isInitialized = false
        mem_alloc = nil
        mem_free = nil
        print_error = nil
        print_warning = nil
        string_new_with_utf8_chars = nil
        string_to_utf8_chars = nil
        string_name_new_with_utf8_chars = nil
        stringDestructor = nil
        stringNameDestructor = nil
        variant_new_copy = nil
        variant_new_nil = nil
        variant_destroy = nil
        variant_get_type = nil
        variant_call = nil
        variant_construct = nil
        variant_set_keyed = nil
        variant_get_keyed = nil
        variant_get_indexed = nil
        variant_get_ptr_destructor = nil
        get_variant_from_type_constructor = nil
        get_variant_to_type_constructor = nil
        variantFromBool = nil
        variantFromInt = nil
        variantFromFloat = nil
        variantFromString = nil
        variantFromStringName = nil
        variantFromObject = nil
        boolFromVariant = nil
        intFromVariant = nil
        floatFromVariant = nil
        stringFromVariant = nil
        stringNameFromVariant = nil
        objectFromVariant = nil
        classdb_register_extension_class = nil
        classdb_register_extension_class2 = nil
        classdb_register_extension_class_method = nil
        classdb_register_extension_class_signal = nil
        classdb_construct_object = nil
        classdb_construct_object3 = nil
        object_destroy = nil
        object_set_instance = nil
        global_get_singleton = nil
        object_method_bind_call = nil
    }
}
