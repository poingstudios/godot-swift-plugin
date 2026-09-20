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

var _plugin: GodotExamplePlugin

@onready var _log_label := $VBoxContainer/ScrollContainer/LogLabel as RichTextLabel
@onready var _btn_ping := $VBoxContainer/GridContainer/BtnPing as Button
@onready var _btn_add := $VBoxContainer/GridContainer/BtnAdd as Button
@onready var _btn_mult := $VBoxContainer/GridContainer/BtnMultiply as Button
@onready var _btn_profile := $VBoxContainer/GridContainer/BtnProfile as Button
@onready var _btn_update_profile := $VBoxContainer/GridContainer/BtnUpdateProfile as Button
@onready var _btn_start_session := $VBoxContainer/GridContainer/BtnStartSession as Button
@onready var _btn_end_session := $VBoxContainer/GridContainer/BtnEndSession as Button
@onready var _btn_sig_profile := $VBoxContainer/GridContainer/BtnSigProfile as Button
@onready var _btn_sig_score := $VBoxContainer/GridContainer/BtnSigScore as Button
@onready var _btn_sig_end := $VBoxContainer/GridContainer/BtnSigEnd as Button
@onready var _btn_switch := $VBoxContainer/BtnSwitchToWrapper as Button


func _ready() -> void:
	_init_plugin()
	_connect_ui_buttons()
	_log("[color=yellow]Direct Swift Sample Ready (No Wrapper, No Singleton).[/color]")

	if DisplayServer.get_name() == "headless":
		_run_headless_verification()


func _init_plugin() -> void:
	if not ClassDB.class_exists("GodotExamplePlugin"):
		_log("[color=red]Error: GodotExamplePlugin is not registered in ClassDB.[/color]")
		return

	_plugin = GodotExamplePlugin.new()
	_plugin.session_ended.connect(_on_session_ended)
	_plugin.user_profile_updated.connect(_on_user_profile_updated)
	_plugin.score_calculated.connect(_on_score_calculated)
	_log("[color=green]Direct instance of GodotExamplePlugin successfully created via .new()[/color]")


func _run_headless_verification() -> void:
	_log("[TEST] Running automated direct class headless verification...")
	_on_btn_ping_pressed()
	_on_btn_add_pressed()
	_on_btn_mult_pressed()
	_on_btn_profile_pressed()
	_on_btn_update_profile_pressed()
	_on_btn_start_session_pressed()
	_on_btn_end_session_pressed()
	if _plugin:
		_plugin.trigger_profile_signal()
		_plugin.trigger_score_signal(999)
		_plugin.trigger_session_end_signal()
	_log("[TEST] Direct class headless verification sequence finished.")


func _connect_ui_buttons() -> void:
	_btn_ping.pressed.connect(_on_btn_ping_pressed)
	_btn_add.pressed.connect(_on_btn_add_pressed)
	_btn_mult.pressed.connect(_on_btn_mult_pressed)
	_btn_profile.pressed.connect(_on_btn_profile_pressed)
	_btn_update_profile.pressed.connect(_on_btn_update_profile_pressed)
	_btn_start_session.pressed.connect(_on_btn_start_session_pressed)
	_btn_end_session.pressed.connect(_on_btn_end_session_pressed)
	_btn_sig_profile.pressed.connect(_on_btn_sig_profile_pressed)
	_btn_sig_score.pressed.connect(_on_btn_sig_score_pressed)
	_btn_sig_end.pressed.connect(_on_btn_sig_end_pressed)
	_btn_switch.pressed.connect(_on_btn_switch_pressed)


func _on_btn_ping_pressed() -> void:
	if not _plugin:
		return
	var response: String = _plugin.ping("DirectCaller")
	_log("[color=cyan]Direct ping response:[/color] %s" % response)


func _on_btn_add_pressed() -> void:
	if not _plugin:
		return
	var result: int = _plugin.add_numbers(15, 27)
	_log("[color=cyan]Direct 15 + 27 =[/color] %d" % result)


func _on_btn_mult_pressed() -> void:
	if not _plugin:
		return
	var result: int = _plugin.multiply_numbers(8, 9)
	_log("[color=cyan]Direct 8 * 9 =[/color] %d" % result)


func _on_btn_profile_pressed() -> void:
	if not _plugin:
		return
	var profile: Dictionary = _plugin.get_user_profile()
	_log("[color=cyan]Direct Profile:[/color] %s" % str(profile))


func _on_btn_update_profile_pressed() -> void:
	if not _plugin:
		return
	var profile: Dictionary = _plugin.update_user_profile("DirectSwiftHero", 77)
	_log("[color=cyan]Direct Updated Profile:[/color] %s" % str(profile))


func _on_btn_start_session_pressed() -> void:
	if not _plugin:
		return
	var success: bool = _plugin.start_session("sess_direct_001")
	var is_active: bool = _plugin.is_session_active()
	_log("[color=cyan]Direct Start session:[/color] %s (active=%s)" % [str(success), str(is_active)])


func _on_btn_end_session_pressed() -> void:
	if not _plugin:
		return
	var success: bool = _plugin.end_session()
	var is_active: bool = _plugin.is_session_active()
	_log("[color=cyan]Direct End session:[/color] %s (active=%s)" % [str(success), str(is_active)])


func _on_btn_sig_profile_pressed() -> void:
	if _plugin:
		_plugin.trigger_profile_signal()


func _on_btn_sig_score_pressed() -> void:
	if _plugin:
		_plugin.trigger_score_signal(777)


func _on_btn_sig_end_pressed() -> void:
	if _plugin:
		_plugin.trigger_session_end_signal()


func _on_btn_switch_pressed() -> void:
	get_tree().change_scene_to_file("res://sample/sample.tscn")


func _on_session_ended() -> void:
	_log("[color=magenta]DIRECT SIGNAL RECEIVED: session_ended[/color]")


func _on_user_profile_updated(profile: Dictionary) -> void:
	_log("[color=magenta]DIRECT SIGNAL RECEIVED: user_profile_updated -> %s[/color]" % str(profile))


func _on_score_calculated(score: int, operation: String) -> void:
	var msg := "[color=magenta]DIRECT SIGNAL RECEIVED: score_calculated -> %d (%s)[/color]"
	_log(msg % [score, operation])


func _log(bbcode: String) -> void:
	print_rich(bbcode)
	if _log_label:
		_log_label.append_text(bbcode + "\n")
