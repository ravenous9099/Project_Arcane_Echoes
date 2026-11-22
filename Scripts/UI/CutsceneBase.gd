class_name CutsceneBase
extends Control
## Lớp nền cho cutscene (bạn tự làm cutscene sau): kế thừa lớp này, khi xong thì gọi finish().
## MainMenu chuyển sang màn chơi khi nhận signal finished. Bấm Esc / Space / Enter / chuột trái sẽ gọi skip() (bỏ qua).
## Ví dụ tối thiểu: tạo scene có root là Control gắn script `extends CutsceneBase`, trong _ready() chạy tween / AnimationPlayer
## rồi gọi finish() ở cuối.

## Cutscene đã xong (hoặc bị bỏ qua).
signal finished

var _done: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_name_to_children.call_deferred()


## Tên người chơi (nhập ở menu chính). Trong cutscene dùng RunStats.player_name hoặc CutsceneBase.format_text("... {name} ...").
static func get_player_name() -> String:
	return RunStats.player_name


## Thay "{name}" (và "{player}") trong chuỗi bằng tên người chơi.
static func format_text(text: String) -> String:
	var n := RunStats.player_name
	return text.replace("{name}", n).replace("{player}", n)


## Tự thay "{name}" / "{player}" trong mọi Label / RichTextLabel / Button có sẵn trong cutscene (gọi 1 lần sau _ready).
## Chữ gán SAU đó (hiệu ứng gõ chữ, đổi thoại bằng code) thì hãy tự gọi format_text() hoặc dùng get_player_name().
func _apply_name_to_children() -> void:
	_apply_name_recursive(self)


func _apply_name_recursive(node: Node) -> void:
	if node is Label:
		(node as Label).text = format_text((node as Label).text)
	elif node is RichTextLabel:
		var rich := node as RichTextLabel
		if rich.bbcode_enabled:
			rich.text = format_text(rich.text)
	elif node is Button:
		(node as Button).text = format_text((node as Button).text)
	for child in node.get_children():
		_apply_name_recursive(child)


func skip() -> void:
	finish()


func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	var skip_pressed := false
	if event is InputEventKey:
		var key := event as InputEventKey
		skip_pressed = key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_SPACE or key.keycode == KEY_ENTER)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		skip_pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if skip_pressed:
		get_viewport().set_input_as_handled()
		skip()
