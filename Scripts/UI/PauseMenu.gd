class_name PauseMenu
extends CanvasLayer
## Menu tạm dừng: phủ tối màn hình, bảng bo góc với Tiếp tục / Chơi lại / Bật-tắt chữ debug / Thoát, kèm tóm tắt lượt chơi
## và nhắc phím điều khiển. Mở/đóng bằng Esc (hoặc nút II trên HUD, hoặc phím P cũ của GameManager).
## Node này chạy cả khi game đang pause (process_mode = ALWAYS) nên nút bấm và phím Esc vẫn hoạt động.

## Người chơi bấm "Chơi lại". Main xử lý (tạo map mới, tự bỏ pause).
signal restart_requested
## Người chơi bấm nút bật/tắt chữ debug. Main chuyển cho HUD.
signal debug_text_toggle_requested

var _hud: CombatHUD = null
var _tracker: ScoreTracker = null
var _root: Control
var _stats: Label
var _debug_button: Button
var _shake_label: Label
var _sfx_label: Label
var _music_label: Label


signal save_requested

var _save_button: Button


## Main bật khi người chơi đang ở sảnh chờ: hiện nút "Lưu game".
func set_save_available(available: bool) -> void:
	if _save_button != null:
		_save_button.visible = available


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	GameManager.pause_changed.connect(_on_pause_changed)
	GameManager.run_started.connect(_close)  # chơi lại / vào lượt mới thì chắc chắn đóng menu


## Cho menu biết HUD (thời gian chơi, trạng thái chữ debug) và bảng điểm để hiện tóm tắt.
func setup(hud: CombatHUD, tracker: ScoreTracker) -> void:
	_hud = hud
	_tracker = tracker
	_hud.debug_text_toggled.connect(func(_visible: bool) -> void: _refresh_debug_button())
	_refresh_debug_button()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	# Chỉ tạm dừng khi đang trong lượt chơi; đang pause thì Esc để tiếp tục.
	if _root.visible or GameManager.is_run_active:
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.02, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	UIStyle.apply_panel(panel, 22, 22.0)
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "TẠM DỪNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(title, 30, 6, UIStyle.ACCENT)
	box.add_child(title)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_stats, 14, 3, Color(0.85, 0.85, 0.9))
	box.add_child(_stats)

	box.add_child(_make_button("Tiếp tục  (Esc)", func() -> void: GameManager.toggle_pause()))
	_save_button = _make_button("Lưu game (chỉ ở sảnh chờ)", func() -> void: save_requested.emit())
	_save_button.visible = false
	box.add_child(_save_button)
	box.add_child(_make_button("Chơi lại  (F5)", func() -> void: restart_requested.emit()))
	_debug_button = _make_button("Chữ debug: Tắt", func() -> void: debug_text_toggle_requested.emit())
	box.add_child(_debug_button)
	_build_settings(box)
	box.add_child(_make_button("Menu chính", _back_to_main_menu))
	box.add_child(_make_button("Thoát game", func() -> void: get_tree().quit()))

	var help := Label.new()
	help.text = "WASD: di chuyển   |   Chuột trái, Q, E, R: spell\nSpace: lướt   |   Tab: kho spell   |   Esc: tạm dừng"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(help, 11, 3, Color(0.7, 0.7, 0.78))
	box.add_child(help)


## Cài đặt cảm giác chiến đấu: chỉnh xong lưu ngay (GameSettings) và áp dụng tức thì qua CombatTuning.
func _build_settings(box: VBoxContainer) -> void:
	var tuning := CombatTuning.current()
	var header := Label.new()
	header.text = "CẢM GIÁC CHIẾN ĐẤU"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(header, 12, 3, Color(0.85, 0.8, 0.6))
	box.add_child(header)

	var shake_row := HBoxContainer.new()
	_shake_label = Label.new()
	_shake_label.custom_minimum_size = Vector2(150, 0)
	UIStyle.apply_label(_shake_label, 13, 3)
	shake_row.add_child(_shake_label)
	var shake_slider := HSlider.new()
	shake_slider.min_value = 0.0
	shake_slider.max_value = 2.0
	shake_slider.step = 0.1
	shake_slider.value = tuning.shake_multiplier
	shake_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shake_slider.value_changed.connect(_on_shake_changed)
	shake_row.add_child(shake_slider)
	box.add_child(shake_row)
	_on_shake_changed(shake_slider.value, false)

	var sfx_row := HBoxContainer.new()
	_sfx_label = Label.new()
	_sfx_label.custom_minimum_size = Vector2(150, 0)
	UIStyle.apply_label(_sfx_label, 13, 3)
	sfx_row.add_child(_sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = db_to_linear(tuning.sfx_volume_db) if tuning.sfx_enabled else 0.0
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(sfx_slider)
	box.add_child(sfx_row)
	_on_sfx_changed(sfx_slider.value, false)

	var music_row := HBoxContainer.new()
	_music_label = Label.new()
	_music_label.custom_minimum_size = Vector2(150, 0)
	UIStyle.apply_label(_music_label, 13, 3)
	music_row.add_child(_music_label)
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = db_to_linear(tuning.music_volume_db) if tuning.music_enabled else 0.0
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_changed)
	music_row.add_child(music_slider)
	box.add_child(music_row)
	_on_music_changed(music_slider.value, false)

	var hitstop_check := CheckButton.new()
	hitstop_check.text = "Hitstop (khựng khi trúng đòn)"
	hitstop_check.button_pressed = tuning.hitstop_enabled
	hitstop_check.focus_mode = Control.FOCUS_NONE
	hitstop_check.toggled.connect(_on_hitstop_toggled)
	box.add_child(hitstop_check)

	var numbers_check := CheckButton.new()
	numbers_check.text = "Hiện số sát thương"
	numbers_check.button_pressed = tuning.damage_numbers_enabled
	numbers_check.focus_mode = Control.FOCUS_NONE
	numbers_check.toggled.connect(_on_numbers_toggled)
	box.add_child(numbers_check)


func _on_shake_changed(value: float, save: bool = true) -> void:
	CombatTuning.current().shake_multiplier = value
	_shake_label.text = "Rung màn hình: %d%%" % int(value * 100.0)
	if save:
		GameSettings.save_from(CombatTuning.current())


func _on_sfx_changed(value: float, save: bool = true) -> void:
	var tuning := CombatTuning.current()
	tuning.sfx_enabled = value > 0.0
	tuning.sfx_volume_db = linear_to_db(maxf(value, 0.001))
	_sfx_label.text = "Âm lượng hiệu ứng: %d%%" % int(value * 100.0)
	if save:
		GameSettings.save_from(tuning)


func _on_music_changed(value: float, save: bool = true) -> void:
	var tuning := CombatTuning.current()
	tuning.music_enabled = value > 0.0
	tuning.music_volume_db = linear_to_db(maxf(value, 0.001))
	_music_label.text = "Âm lượng nhạc nền: %d%%" % int(value * 100.0)
	if save:
		GameSettings.save_from(tuning)
		MusicPlayer.refresh_volume()


func _on_hitstop_toggled(pressed: bool) -> void:
	CombatTuning.current().hitstop_enabled = pressed
	GameSettings.save_from(CombatTuning.current())


func _on_numbers_toggled(pressed: bool) -> void:
	CombatTuning.current().damage_numbers_enabled = pressed
	GameSettings.save_from(CombatTuning.current())


## Về màn hình chính (bỏ lượt chơi hiện tại). Nếu chưa có scene menu thì không làm gì.
func _back_to_main_menu() -> void:
	const MENU_PATH := "res://Scenes/UI/MainMenu.tscn"
	if not ResourceLoader.exists(MENU_PATH):
		push_warning("PauseMenu: chưa có %s." % MENU_PATH)
		return
	get_tree().paused = false
	GameManager.is_run_active = false
	SpellSystem.reset()
	get_tree().change_scene_to_file(MENU_PATH)


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	UIStyle.apply_button(button, 14, 15)
	button.pressed.connect(on_pressed)
	return button


func _on_pause_changed(is_paused: bool) -> void:
	_root.visible = is_paused
	if is_paused:
		_refresh_stats()
		_refresh_debug_button()


func _close() -> void:
	_root.visible = false


func _refresh_stats() -> void:
	var lines := PackedStringArray()
	if _hud != null:
		lines.append("Thời gian: %s" % CombatHUD.format_time(_hud.get_run_time()))
	if _tracker != null:
		lines.append("Điểm: %d / %d   |   Hạ gục: %d" % [_tracker.score, _tracker.score_goal, _tracker.total_kills])
	_stats.text = "\n".join(lines)


func _refresh_debug_button() -> void:
	if _debug_button != null and _hud != null:
		_debug_button.text = "Chữ debug: Bật" if _hud.is_debug_text_visible() else "Chữ debug: Tắt"
