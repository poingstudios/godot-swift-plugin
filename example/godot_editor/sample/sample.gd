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

extends Control

@onready var _log_label: RichTextLabel = $VBoxContainer/ScrollContainer/LogLabel
@onready var _btn_ping: Button = $VBoxContainer/GridContainer/BtnPing
@onready var _btn_add: Button = $VBoxContainer/GridContainer/BtnAdd
@onready var _btn_mult: Button = $VBoxContainer/GridContainer/BtnMultiply
@onready var _btn_profile: Button = $VBoxContainer/GridContainer/BtnProfile
@onready var _btn_update_profile: Button = $VBoxContainer/GridContainer/BtnUpdateProfile
@onready var _btn_start_session: Button = $VBoxContainer/GridContainer/BtnStartSession
@onready var _btn_end_session: Button = $VBoxContainer/GridContainer/BtnEndSession
@onready var _btn_sig_profile: Button = $VBoxContainer/GridContainer/BtnSigProfile
@onready var _btn_sig_score: Button = $VBoxContainer/GridContainer/BtnSigScore
@onready var _btn_sig_end: Button = $VBoxContainer/GridContainer/BtnSigEnd


func _ready() -> void:
	_connect_plugin_signals()
	_connect_ui_buttons()
	_log("[color=yellow]Godot Swift Plugin Sample Ready.[/color]")
	var singleton := ExamplePlugin.get_singleton()
	if singleton:
		_log("[color=green]Native 'Example' singleton found![/color]")
	else:
		_log("[color=orange]Native 'Example' singleton not found. Running in fallback mode.[/color]")

	if DisplayServer.get_name() == "headless":
		_run_headless_verification()


func _run_headless_verification() -> void:
	_log("[TEST] Running automated headless verification...")
	_on_btn_ping_pressed()
	_on_btn_add_pressed()
	_on_btn_mult_pressed()
	_on_btn_profile_pressed()
	_on_btn_update_profile_pressed()
	_on_btn_start_session_pressed()
	_on_btn_end_session_pressed()
	ExamplePlugin.trigger_profile_signal()
	ExamplePlugin.trigger_score_signal(999)
	ExamplePlugin.trigger_session_end_signal()
	_log("[TEST] Headless verification sequence finished.")


func _connect_plugin_signals() -> void:
	ExamplePlugin.session_ended.connect(_on_session_ended)
	ExamplePlugin.user_profile_updated.connect(_on_user_profile_updated)
	ExamplePlugin.score_calculated.connect(_on_score_calculated)


func _connect_ui_buttons() -> void:
	_btn_ping.pressed.connect(_on_btn_ping_pressed)
	_btn_add.pressed.connect(_on_btn_add_pressed)
	_btn_mult.pressed.connect(_on_btn_mult_pressed)
	_btn_profile.pressed.connect(_on_btn_profile_pressed)
	_btn_update_profile.pressed.connect(_on_btn_update_profile_pressed)
	_btn_start_session.pressed.connect(_on_btn_start_session_pressed)
	_btn_end_session.pressed.connect(_on_btn_end_session_pressed)
	_btn_sig_profile.pressed.connect(ExamplePlugin.trigger_profile_signal)
	_btn_sig_score.pressed.connect(func() -> void: ExamplePlugin.trigger_score_signal(777))
	_btn_sig_end.pressed.connect(ExamplePlugin.trigger_session_end_signal)


func _on_btn_ping_pressed() -> void:
	var response := ExamplePlugin.ping("Godot Dev")
	_log("[color=cyan]Ping response:[/color] %s" % response)


func _on_btn_add_pressed() -> void:
	var result := ExamplePlugin.add_numbers(15, 27)
	_log("[color=cyan]15 + 27 =[/color] %d" % result)


func _on_btn_mult_pressed() -> void:
	var result := ExamplePlugin.multiply_numbers(8, 9)
	_log("[color=cyan]8 * 9 =[/color] %d" % result)


func _on_btn_profile_pressed() -> void:
	var profile := ExamplePlugin.get_user_profile()
	_log("[color=cyan]Profile:[/color] %s" % str(profile))


func _on_btn_update_profile_pressed() -> void:
	var profile := ExamplePlugin.update_user_profile("SwiftHero", 42)
	_log("[color=cyan]Updated Profile:[/color] %s" % str(profile))


func _on_btn_start_session_pressed() -> void:
	var success := ExamplePlugin.start_session("sess_swift_001")
	var is_active := ExamplePlugin.is_session_active()
	_log("[color=cyan]Start session:[/color] %s (active=%s)" % [str(success), str(is_active)])


func _on_btn_end_session_pressed() -> void:
	var success := ExamplePlugin.end_session()
	var is_active := ExamplePlugin.is_session_active()
	_log("[color=cyan]End session:[/color] %s (active=%s)" % [str(success), str(is_active)])


func _on_session_ended() -> void:
	_log("[color=magenta]SIGNAL RECEIVED: session_ended[/color]")


func _on_user_profile_updated(profile: Dictionary) -> void:
	_log("[color=magenta]SIGNAL RECEIVED: user_profile_updated -> %s[/color]" % str(profile))


func _on_score_calculated(score: int, operation: String) -> void:
	_log("[color=magenta]SIGNAL RECEIVED: score_calculated -> %d (%s)[/color]" % [score, operation])


func _log(bbcode: String) -> void:
	print_rich(bbcode)
	if _log_label:
		_log_label.append_text(bbcode + "\n")
