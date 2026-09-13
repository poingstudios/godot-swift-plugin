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

#import <Foundation/Foundation.h>

#include "GodotSwiftBridge.h"
#include "core/config/engine.h"
#include "core/io/json.h"
#include "core/object/class_db.h"
#include "core/templates/hash_map.h"
#include "core/templates/vector.h"



extern "C" {
typedef void (*GodotSignalCallback)(const char *plugin_name, const char *signal_name, const char *json_args);
typedef void (*GodotFocusCallback)();

void godot_swift_free_string(const char *ptr);
void godot_swift_set_signal_callback(GodotSignalCallback callback);
void godot_swift_set_focus_callbacks(GodotFocusCallback focus_out, GodotFocusCallback focus_in);

int godot_swift_get_plugin_count();
const char *godot_swift_get_plugin_name(int index);
const char *godot_swift_get_methods(const char *plugin_name);
const char *godot_swift_get_signals(const char *plugin_name);
const char *godot_swift_call_method(const char *plugin_name, const char *method_name, const char *json_args);
}

static HashMap<String, GodotSwiftSingleton *> g_swift_singletons;

static void _godot_swift_signal_handler(const char *c_plugin_name, const char *c_signal_name, const char *c_json_args) {
	String plugin_name = String::utf8(c_plugin_name);
	String signal_name = String::utf8(c_signal_name);
	String json_args = String::utf8(c_json_args);

	auto emit_block = [plugin_name, signal_name, json_args]() {
		if (!g_swift_singletons.has(plugin_name)) {
			return;
		}

		GodotSwiftSingleton *singleton = g_swift_singletons[plugin_name];
		if (!singleton) {
			return;
		}

		Variant parsed = JSON::parse_string(json_args);
		if (parsed.get_type() == Variant::ARRAY) {
			Array arr = parsed;
			int count = arr.size();
			Vector<const Variant *> argptrs;
			argptrs.resize(count);
			for (int i = 0; i < count; i++) {
				argptrs.write[i] = &arr[i];
			}
			singleton->emit_signalp(StringName(signal_name), count == 0 ? nullptr : (const Variant **)argptrs.ptr(), count);
		} else {
			singleton->emit_signal(StringName(signal_name));
		}
	};

	if ([NSThread isMainThread]) {
		emit_block();
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			emit_block();
		});
	}
}

static void _godot_swift_bridge_focus_out() {
}

static void _godot_swift_bridge_focus_in() {
}

void GodotSwiftSingleton::add_signal(const String &p_name) {
	MethodInfo mi(p_name);
	add_user_signal(mi);
}

Variant GodotSwiftSingleton::callp(const StringName &p_method, const Variant **p_args, int p_argcount, Callable::CallError &r_error) {
	if (ClassDB::has_method("Object", p_method)) {
		return Object::callp(p_method, p_args, p_argcount, r_error);
	}

	Array godot_args;
	for (int i = 0; i < p_argcount; i++) {
		godot_args.push_back(*p_args[i]);
	}
	String json_args = JSON::stringify(godot_args);

	const char *res_ptr = godot_swift_call_method(
			plugin_name.utf8().get_data(),
			String(p_method).utf8().get_data(),
			json_args.utf8().get_data());

	if (res_ptr) {
		String res_str = String::utf8(res_ptr);
		godot_swift_free_string(res_ptr);
		Variant result = JSON::parse_string(res_str);
		r_error.error = Callable::CallError::CALL_OK;
		return result;
	}

	r_error.error = Callable::CallError::CALL_ERROR_INVALID_METHOD;
	return Variant();
}

GodotSwiftSingleton::GodotSwiftSingleton(const String &p_name) :
		plugin_name(p_name) {
}

GodotSwiftSingleton::~GodotSwiftSingleton() {
}

void godot_swift_initialize_embedded_plugins() {
	godot_swift_set_signal_callback(&_godot_swift_signal_handler);
	godot_swift_set_focus_callbacks(&_godot_swift_bridge_focus_out, &_godot_swift_bridge_focus_in);

	int count = godot_swift_get_plugin_count();
	for (int i = 0; i < count; i++) {
		const char *name_c = godot_swift_get_plugin_name(i);
		if (!name_c) {
			continue;
		}

		String plugin_name = String::utf8(name_c);
		godot_swift_free_string(name_c);

		GodotSwiftSingleton *singleton = memnew(GodotSwiftSingleton(plugin_name));

		const char *signals_json = godot_swift_get_signals(plugin_name.utf8().get_data());
		if (signals_json) {
			Variant parsed = JSON::parse_string(String::utf8(signals_json));
			godot_swift_free_string(signals_json);

			if (parsed.get_type() == Variant::ARRAY) {
				Array signals_array = parsed;
				for (int s = 0; s < signals_array.size(); s++) {
					singleton->add_signal(signals_array[s]);
				}
			}
		}

		Engine::get_singleton()->add_singleton(Engine::Singleton(plugin_name, singleton));
		g_swift_singletons[plugin_name] = singleton;
	}
}

void godot_swift_deinitialize_embedded_plugins() {
	for (const KeyValue<String, GodotSwiftSingleton *> &E : g_swift_singletons) {
		Engine::get_singleton()->remove_singleton(E.key);
		memdelete(E.value);
	}
	g_swift_singletons.clear();
}
