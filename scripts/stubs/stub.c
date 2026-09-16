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

/**
 * Minimal GDExtension stub functions for unsupported platforms.
 * These do nothing but satisfy Godot's requirement for a valid entry point,
 * silencing "No GDExtension library found for current OS and architecture" errors.
 */

#ifdef _WIN32
#define STUB_EXPORT __declspec(dllexport)
#else
#define STUB_EXPORT __attribute__((visibility("default")))
#endif

void stub_dummy_func(void *userdata, int level) {}

typedef struct {
    int minimum_initialization_level;
    void *userdata;
    void (*initialize)(void *userdata, int p_level);
    void (*deinitialize)(void *userdata, int p_level);
} GDExtensionInitialization;

/**
 * GDExtension Entry Point
 * Returns 1 (success) and sets dummy initialization callbacks.
 */
STUB_EXPORT unsigned char godot_swift_extension_init(
    void *p_get_proc_address,
    void *p_library,
    GDExtensionInitialization *r_initialization
) {
    if (r_initialization) {
        r_initialization->initialize = stub_dummy_func;
        r_initialization->deinitialize = stub_dummy_func;
        r_initialization->minimum_initialization_level = 0;
    }
    return 1;
}
