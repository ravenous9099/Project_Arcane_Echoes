class_name IntroCutscene
extends CutsceneBase
## Cutscene mở đầu mặc định (MainMenu dùng khi bạn chưa gán cutscene riêng vào cutscene_scene): cuộc trò chuyện giữa Người Giữ Đèn và người chơi,
## có tên người chơi (RunStats.player_name). Bấm Enter / Space / chuột trái để sang câu kế, Esc để bỏ qua toàn bộ.
## Muốn viết lại: sửa mảng LINES (dùng {name} cho tên người chơi), hoặc làm cutscene riêng extends CutsceneBase rồi gán vào MainMenu.

const LINES: Array[Dictionary] = [
	{"who": "", "text": "Vực Tiếng Vọng - nơi mọi phép thuật đều để lại dư âm, và dư âm ấy đã hóa thành quái vật."},
	{"who": "Người Giữ Đèn", "text": "Lại có kẻ dám bước tới ngưỡng cửa này sao? Ngươi tên là gì, lữ khách?"},
	{"who": "{name}", "text": "Tôi là {name}. Tôi đến để chấm dứt những tiếng vọng đó."},
	{"who": "Người Giữ Đèn", "text": "{name}... ta sẽ khắc cái tên ấy lên ngọn đèn này. Ba Chúa tể đang canh giữ những tầng hầm ngục."},
	{"who": "Người Giữ Đèn", "text": "Hạ từng tên một, mang vàng về sảnh, Relic Merchant sẽ đổi cho ngươi những báu vật. Hãy sống sót, {name}."},
]

var _index: int = -1
var _who_label: Label
var _text_label: Label
var _hint: Label
var _typing: Tween


func _ready() -> void:
	super._ready()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.01, 0.05)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 80.0
	panel.offset_right = -80.0
	panel.offset_top = -210.0
	panel.offset_bottom = -50.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_panel(panel, 16, 18.0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_who_label = Label.new()
	UIStyle.apply_label(_who_label, 20, 4, UIStyle.ACCENT)
	box.add_child(_who_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(900.0, 70.0)
	UIStyle.apply_label(_text_label, 20, 4)
	box.add_child(_text_label)
	_hint = Label.new()
	_hint.text = "Enter / Space / chuột: tiếp  •  Esc: bỏ qua"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.apply_label(_hint, 13, 3, Color(0.7, 0.72, 0.85, 0.8))
	box.add_child(_hint)
	_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= LINES.size():
		finish()
		return
	var line := LINES[_index]
	var who := format_text(String(line["who"]))
	_who_label.text = who
	_who_label.visible = not who.is_empty()
	_text_label.text = format_text(String(line["text"]))
	_text_label.visible_ratio = 0.0
	if _typing != null:
		_typing.kill()
	var duration := maxf(0.6, float(_text_label.text.length()) * 0.028)
	_typing = create_tween()
	_typing.tween_property(_text_label, "visible_ratio", 1.0, duration)


func _unhandled_input(event: InputEvent) -> void:
	var advance := false
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			skip()
			return
		advance = key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		advance = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _text_label.visible_ratio < 1.0:  # đang gõ chữ: hiện đủ câu trước
		if _typing != null:
			_typing.kill()
		_text_label.visible_ratio = 1.0
	else:
		_next_line()
