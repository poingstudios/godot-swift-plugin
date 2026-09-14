# MIT License
#
# Copyright (c) 2026-present Poing Studios
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class_name ExamplePlugin

const ExampleLogger := preload("res://addons/example_plugin/internal/example_logger.gd")

class _SignalDispatcher:
	extends RefCounted
	signal session_ended
	signal user_profile_updated(profile: Dictionary)
	signal score_calculated(score: int, operation: String)

static var _dispatcher := _SignalDispatcher.new()
static var session_ended := _dispatcher.session_ended
static var user_profile_updated := _dispatcher.user_profile_updated
static var score_calculated := _dispatcher.score_calculated

static var _plugin := _get_plugin()


static func _get_plugin() -> Object:
	if Engine.has_singleton("Example"):
		var plugin := Engine.get_singleton("Example")
		if plugin:
			if not plugin.is_connected("session_ended", _on_session_ended):
				plugin.connect("session_ended", _on_session_ended)
			if not plugin.is_connected("user_profile_updated", _on_user_profile_updated):
				plugin.connect("user_profile_updated", _on_user_profile_updated)
			if not plugin.is_connected("score_calculated", _on_score_calculated):
				plugin.connect("score_calculated", _on_score_calculated)
		return plugin
	return null


static func _on_session_ended() -> void:
	ExampleLogger.info("Signal received: session_ended")
	_dispatcher.session_ended.emit()


static func _on_user_profile_updated(profile: Dictionary) -> void:
	ExampleLogger.info("Signal received: user_profile_updated -> %s" % str(profile))
	_dispatcher.user_profile_updated.emit(profile)


static func _on_score_calculated(score: int, operation: String) -> void:
	ExampleLogger.info("Signal received: score_calculated -> %d (%s)" % [score, operation])
	_dispatcher.score_calculated.emit(score, operation)


static func ping(message: String) -> String:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.ping(message) as String
	return "Mock fallback: Hello %s (Plugin not loaded)" % message


static func add_numbers(a: int, b: int) -> int:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.add_numbers(a, b) as int
	return a + b


static func multiply_numbers(a: int, b: int) -> int:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.multiply_numbers(a, b) as int
	return a * b


static func get_user_profile() -> Dictionary:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.get_user_profile() as Dictionary
	return {"name": "OfflineUser", "level": 0}


static func update_user_profile(name: String, level: int) -> Dictionary:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.update_user_profile(name, level) as Dictionary
	return {"name": name, "level": level}


static func start_session(session_id: String) -> bool:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.start_session(session_id) as bool
	return true


static func end_session() -> bool:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.end_session() as bool
	return true


static func is_session_active() -> bool:
	var plugin := _ensure_plugin()
	if plugin:
		return plugin.is_session_active() as bool
	return false


static func trigger_profile_signal() -> void:
	var plugin := _ensure_plugin()
	if plugin:
		plugin.trigger_profile_signal()


static func trigger_score_signal(score: int) -> void:
	var plugin := _ensure_plugin()
	if plugin:
		plugin.trigger_score_signal(score)


static func trigger_session_end_signal() -> void:
	var plugin := _ensure_plugin()
	if plugin:
		plugin.trigger_session_end_signal()


static func get_singleton() -> Object:
	return _ensure_plugin()


static func _ensure_plugin() -> Object:
	if _plugin == null:
		_plugin = _get_plugin()
	return _plugin
