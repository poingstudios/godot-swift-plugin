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
@_exported import CGDExtensionInterface

private var g_get_proc_address: GDExtensionInterfaceGetProcAddress?
private var g_library: GDExtensionClassLibraryPtr?

/// Internal GDExtension lifecycle initialization callback.
private func godot_swift_init_level(
    _ userdata: UnsafeMutableRawPointer?,
    _ level: GDExtensionInitializationLevel
) {
    guard level == GDEXTENSION_INITIALIZATION_SCENE,
          let getProcAddress = g_get_proc_address else {
        return
    }

    GodotInterface.shared.load(getProcAddress: getProcAddress, library: g_library)
    GodotPluginRegistry.shared.initializeAllPlugins()
}

/// Internal GDExtension lifecycle deinitialization callback.
private func godot_swift_deinit_level(
    _ userdata: UnsafeMutableRawPointer?,
    _ level: GDExtensionInitializationLevel
) {
    guard level == GDEXTENSION_INITIALIZATION_SCENE else { return }

    GodotPluginRegistry.shared.deinitializeAllPlugins()
    GodotClassDB.shared.reset()
    GodotStringName.clearCache()
    GodotString.clearCache()
    GodotInterface.shared.reset()
}

/// Helper coordinating standard GDExtension entry points.
public enum GodotBridge {
    /// Initializes a GDExtension Swift plugin library.
    public static func initializeExtension(
        getProcAddress: GDExtensionInterfaceGetProcAddress?,
        library: GDExtensionClassLibraryPtr?,
        initialization: UnsafeMutablePointer<GDExtensionInitialization>?
    ) -> GDExtensionBool {
        guard let getProcAddress, let initialization else {
            return 0
        }

        g_get_proc_address = getProcAddress
        g_library = library

        initialization.pointee.initialize = godot_swift_init_level
        initialization.pointee.deinitialize = godot_swift_deinit_level
        initialization.pointee.userdata = nil
        initialization.pointee.minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE

        return 1
    }

    /// Initializes a GDExtension Swift plugin library and registers a specific plugin type.
    public static func initializeExtension<T: GodotPlugin>(
        pluginType: T.Type,
        factory: @escaping () -> T,
        getProcAddress: GDExtensionInterfaceGetProcAddress?,
        library: GDExtensionClassLibraryPtr?,
        initialization: UnsafeMutablePointer<GDExtensionInitialization>?
    ) -> GDExtensionBool {
        GodotPluginRegistry.shared.registerPlugin(factory())
        return initializeExtension(
            getProcAddress: getProcAddress,
            library: library,
            initialization: initialization
        )
    }
}

// MARK: - Standard GDExtension Entry Symbol

@_cdecl("godot_swift_extension_init")
public func godot_swift_extension_init(
    _ p_get_proc_address: GDExtensionInterfaceGetProcAddress?,
    _ p_library: GDExtensionClassLibraryPtr?,
    _ r_initialization: UnsafeMutablePointer<GDExtensionInitialization>?
) -> GDExtensionBool {
    return GodotBridge.initializeExtension(
        getProcAddress: p_get_proc_address,
        library: p_library,
        initialization: r_initialization
    )
}
