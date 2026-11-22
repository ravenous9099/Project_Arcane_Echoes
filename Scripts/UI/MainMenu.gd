class_name MainMenu
extends Control
## Màn hình chính trước khi vào game: 2 nút "CHƠI MỚI" và "THOÁT GAME".
## Hình nền được DỰNG BẰNG CODE từ chính sprite của game (không cần file ảnh): trời đêm có trăng-ma-pháp, ba Boss to lớn lấp ló phía sau,
## nhân vật chính (pháp sư) đứng giữa, hàng quái đứng hàng đầu, đom đóm lửa bay lên. Bố cục lấy ý tưởng từ Wizard of Legend:
## tiêu đề và menu căn trái, nhân vật chính ở bên phải nhìn về phía menu.
## Muốn dùng ảnh riêng: kéo ảnh vào background_texture / logo_texture (ảnh nền thay phần trời, logo thay chữ tiêu đề); tắt show_characters
## nếu không muốn hiện nhân vật.
##
## "Chơi mới": trước tiên hiện bảng nhập tên (xưng danh, lưu vào RunStats.player_name); sau đó nếu đã gán cutscene_scene thì phát cutscene (scene gốc kế thừa CutsceneBase, phát signal finished) rồi vào game;
## chưa gán thì phát IntroCutscene mặc định (lời thoại có tên người chơi). Nút "Hall of Fame" mở bảng điểm cao. Phím: W/S hoặc mũi tên chọn nút, Enter/Space xác nhận.

const CHAR_ROOT := "res://Assets/Characters/2D HD Character pack/Spritesheets/With shadow/"

## Scene của màn chơi.
@export_file("*.tscn") var game_scene_path: String = "res://Main/Main.tscn"
## Cutscene sau khi bấm "Chơi mới" (để trống = vào game ngay). Root của scene nên extends CutsceneBase.
@export var cutscene_scene: PackedScene
@export_group("Hình ảnh (để trống = dùng hình dựng bằng code)")
@export var background_texture: Texture2D
@export var logo_texture: Texture2D
## Tên game hiện bằng chữ khi chưa có logo.
@export var title_text: String = "ARCANE ECHOES"
@export var subtitle_text: String = "The Forgotten Trials"
## Hiện nhân vật chính / Boss / quái ở nền.
@export var show_characters: bool = true

## Nhân vật dựng ở nền: {folder, x, y (tỉ lệ màn hình), scale, row (hướng nhìn), tint, layer}. Hàng 0..7 = SE, S, SW, W, NW, N, NE, E.
const CAST: Array[Dictionary] = [
	{"folder": "8DarkLord", "x": 0.665, "y": 0.80, "scale": 4.6, "row": 2, "tint": Color(0.55, 0.4, 0.78), "glow": Color(0.7, 0.3, 1.0)},
	{"folder": "7DeathKnight", "x": 0.455, "y": 0.82, "scale": 4.0, "row": 2, "tint": Color(0.75, 0.38, 0.38), "glow": Color(1.0, 0.3, 0.2)},
	{"folder": "9Longbow", "x": 0.93, "y": 0.80, "scale": 4.0, "row": 2, "tint": Color(0.5, 0.7, 0.9), "glow": Color(0.4, 0.8, 1.0)},
	{"folder": "1Knight", "x": 0.54, "y": 0.99, "scale": 2.4, "row": 2, "tint": Color(0.55, 0.55, 0.65), "glow": Color(0, 0, 0, 0)},
	{"folder": "4Paladin", "x": 0.62, "y": 1.0, "scale": 2.5, "row": 2, "tint": Color(0.55, 0.55, 0.65), "glow": Color(0, 0, 0, 0)},
	{"folder": "3Wizard", "x": 0.47, "y": 1.02, "scale": 2.3, "row": 2, "tint": Color(0.55, 0.55, 0.7), "glow": Color(0, 0, 0, 0)},
	{"folder": "5CamoArcher", "x": 0.97, "y": 1.02, "scale": 2.3, "row": 2, "tint": Color(0.6, 0.65, 0.8), "glow": Color(0, 0, 0, 0)},
	{"folder": "2Archer", "x": 0.88, "y": 1.03, "scale": 2.3, "row": 2, "tint": Color(0.55, 0.55, 0.65), "glow": Color(0, 0, 0, 0)},
	{"folder": "6Mage", "x": 0.775, "y": 0.93, "scale": 4.2, "row": 2, "tint": Color(1, 1, 1), "glow": Color(1.0, 0.75, 0.35)},
]

var _menu_root: Control
var _backdrop: Control
var _stage: Node2D
var _actors: Array[AnimatedSprite2D] = []
var _buttons: Array[Button] = []
var _selected: int = 0
var _busy: bool = false
var _time: float = 0.0
var _stars: PackedVector2Array = PackedVector2Array()
var _embers: Array[Dictionary] = []
var _overlay: Control = null  # bảng nhập tên hoặc Hall of Fame đang mở
var _name_edit: LineEdit = null
var _name_error: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260
	for i in 90:
		_stars.append(Vector2(rng.randf(), rng.randf() * 0.7))
	for i in 46:
		_embers.append({"x": rng.randf(), "phase": rng.randf(), "speed": rng.randf_range(0.04, 0.12), "size": rng.randf_range(1.2, 3.0), "warm": rng.randf() < 0.7})
	MusicPlayer.play_track(&"menu")
	_build_ui()
	resized.connect(_layout_stage)
	_layout_stage()
	_select(0)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_time += delta
	if _backdrop != null:
		_backdrop.queue_redraw()
	# Nhân vật chính và Boss "thở" nhẹ.
	for i in _actors.size():
		var actor := _actors[i]
		var base: Vector2 = actor.get_meta("base_scale")
		var breathe := 1.0 + 0.012 * sin(_time * 1.6 + float(i))
		actor.scale = Vector2(base.x, base.y * breathe)


func _unhandled_input(event: InputEvent) -> void:
	if _busy or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _overlay != null:  # đang mở bảng nhập tên / Hall of Fame: chỉ Esc để đóng
		if key.keycode == KEY_ESCAPE:
			_close_overlay()
			get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_W, KEY_UP:
			_select(posmod(_selected - 1, _buttons.size()))
		KEY_S, KEY_DOWN:
			_select(posmod(_selected + 1, _buttons.size()))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_buttons[_selected].pressed.emit()
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Dựng giao diện
func _build_ui() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_root)

	_backdrop = Control.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_on_backdrop_draw)
	_menu_root.add_child(_backdrop)

	_stage = Node2D.new()
	_menu_root.add_child(_stage)
	if show_characters:
		_build_cast()

	var front := Control.new()  # lớp phủ tối + sương phía trước nhân vật
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_on_front_draw.bind(front))
	_menu_root.add_child(front)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.anchor_right = 0.5
	column.offset_left = 72.0
	column.offset_right = 0.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(column)

	if logo_texture != null:
		var logo := TextureRect.new()
		logo.texture = logo_texture
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.custom_minimum_size = Vector2(0.0, 150.0)
		logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(logo)
	else:
		var title := Label.new()
		title.text = title_text
		UIStyle.apply_label(title, 66, 8, Color(1.0, 0.86, 0.42))
		title.add_theme_color_override("font_shadow_color", Color(0.9, 0.4, 0.1, 0.55))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 4)
		column.add_child(title)
	var ornament := Control.new()  # đường kẻ trang trí có hình thoi giữa, ngăn tiêu đề và tiêu đề phụ
	ornament.custom_minimum_size = Vector2(440.0, 20.0)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.draw.connect(_on_ornament_draw.bind(ornament))
	column.add_child(ornament)
	var subtitle := Label.new()
	subtitle.text = subtitle_text.to_upper()
	UIStyle.apply_label(subtitle, 20, 3, Color(0.82, 0.78, 1.0))
	var spaced := FontVariation.new()  # giãn chữ cho tiêu đề phụ
	spaced.base_font = ThemeDB.fallback_font
	spaced.spacing_glyph = 7
	subtitle.add_theme_font_override("font", spaced)
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 28.0)
	column.add_child(spacer)

	var start := _make_button("CHƠI MỚI", _on_start_pressed)
	var fame := _make_button("HALL OF FAME", _on_fame_pressed)
	var quit := _make_button("THOÁT GAME", _on_quit_pressed)
	_buttons = [start, fame, quit]
	if SaveSystem.has_save():  # có file lưu ở sảnh chờ: thêm nút "Tiếp tục" lên đầu và chọn sẵn
		_buttons.insert(0, _make_button("TIẾP TỤC", _on_continue_pressed))
	for b in _buttons:
		column.add_child(b)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for i in _buttons.size():
		_buttons[i].mouse_entered.connect(_select.bind(i))

	var hint := Label.new()
	hint.text = "W/S hoặc ↑/↓ chọn  •  Enter xác nhận"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(72.0, -40.0)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UIStyle.apply_label(hint, 13, 3, Color(0.7, 0.72, 0.85, 0.8))
	_menu_root.add_child(hint)


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(320.0, 56.0)
	UIStyle.apply_button(button, 10, 22)
	button.pressed.connect(on_pressed)
	return button


## Làm nổi bật nút đang chọn (dùng kiểu "hover" của UIStyle) và gắn dấu ▶.
func _select(index: int) -> void:
	_selected = index
	for i in _buttons.size():
		var b := _buttons[i]
		var base_text := b.text.trim_prefix("▶  ")
		if i == _selected:
			b.text = "▶  " + base_text
			b.add_theme_stylebox_override("normal", UIStyle.box(10, Color(0.26, 0.2, 0.36, 0.96), UIStyle.ACCENT))
			b.add_theme_color_override("font_color", UIStyle.ACCENT)
		else:
			b.text = base_text
			b.add_theme_stylebox_override("normal", UIStyle.box(10, Color(0.1, 0.09, 0.16, 0.85)))
			b.add_theme_color_override("font_color", Color(0.85, 0.83, 0.9))


func _build_cast() -> void:
	for entry in CAST:
		var frames := CharacterFrames.build(CHAR_ROOT + String(entry["folder"]), {"idle": "Idle"}, {"idle": true}, 128, 10.0)
		if frames == null:
			continue
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		var anim := "idle_%d" % int(entry["row"])
		if not frames.has_animation(anim):
			anim = "idle_0"
		sprite.play(anim)
		sprite.frame = randi() % maxi(frames.get_frame_count(anim), 1)
		sprite.modulate = entry["tint"]
		sprite.set_meta("cfg", entry)
		sprite.set_meta("base_scale", Vector2.ONE)
		_stage.add_child(sprite)
		_actors.append(sprite)


## Đặt vị trí/kích thước nhân vật theo kích thước màn hình hiện tại (thiết kế cho 648 px chiều cao).
func _layout_stage() -> void:
	if _stage == null:
		return
	var k := size.y / 648.0
	for sprite in _actors:
		var cfg: Dictionary = sprite.get_meta("cfg")
		sprite.position = Vector2(size.x * float(cfg["x"]), size.y * float(cfg["y"]) - 60.0 * k * float(cfg["scale"]) * 0.5)
		var s := float(cfg["scale"]) * k
		sprite.set_meta("base_scale", Vector2(s, s))
		sprite.scale = Vector2(s, s)


# ---------------------------------------------------------------- Vẽ nền
func _on_backdrop_draw() -> void:
	var w := _backdrop.size.x
	var h := _backdrop.size.y
	if background_texture != null:
		_backdrop.draw_texture_rect(background_texture, Rect2(Vector2.ZERO, _backdrop.size), false)
	else:
		# Trời đêm: gradient dọc tím đen -> xanh thẫm -> tím ở chân trời.
		var bands := 24
		for i in bands:
			var t := float(i) / float(bands - 1)
			var c := Color(0.02, 0.02, 0.07).lerp(Color(0.1, 0.06, 0.2), pow(t, 1.6)).lerp(Color(0.25, 0.1, 0.22), pow(t, 4.0) * 0.8)
			_backdrop.draw_rect(Rect2(0.0, h * float(i) / float(bands), w, h / float(bands) + 1.0), c)
		for s in _stars.size():
			var p := _stars[s]
			var twinkle := 0.5 + 0.5 * sin(_time * 1.3 + float(s) * 1.7)
			_backdrop.draw_circle(Vector2(p.x * w, p.y * h), 1.0 + (s % 3) * 0.4, Color(0.85, 0.9, 1.0, 0.25 + 0.5 * twinkle))
		# Trăng ma thuật + các vòng rune xoay chậm sau nhân vật chính.
		var moon := Vector2(w * 0.74, h * 0.38)
		var mr := h * 0.2
		for g in 6:
			_backdrop.draw_circle(moon, mr * (1.9 - 0.15 * g), Color(0.6, 0.45, 1.0, 0.025 + 0.015 * g))
		_backdrop.draw_circle(moon, mr, Color(0.9, 0.88, 1.0, 0.92))
		for ring in 3:
			var rr := mr * (1.35 + 0.28 * ring)
			var spin := _time * (0.15 if ring % 2 == 0 else -0.1)
			for seg in 12:
				var a0 := spin + TAU * float(seg) / 12.0
				_backdrop.draw_arc(moon, rr, a0, a0 + TAU / 12.0 * 0.62, 10, Color(0.75, 0.6, 1.0, 0.35 - ring * 0.07), 2.0)
	_draw_landscape(w, h)
	# Vầng sáng tím sau khu vực tiêu đề để chữ nổi bật.
	for g in 7:
		_backdrop.draw_circle(Vector2(w * 0.2, h * 0.3), h * (0.5 - 0.055 * g), Color(0.55, 0.3, 0.9, 0.02 + 0.006 * g))
	# Vầng sáng sau Boss và nhân vật chính (màu riêng từng người).
	for sprite in _actors:
		var cfg: Dictionary = sprite.get_meta("cfg")
		var glow: Color = cfg["glow"]
		if glow.a <= 0.0:
			continue
		var base_s: Vector2 = sprite.get_meta("base_scale")
		var radius := 128.0 * base_s.x * 0.42
		for g in 6:
			_backdrop.draw_circle(sprite.position + Vector2(0.0, radius * 0.1), radius * (1.25 - 0.17 * g), Color(glow, 0.035 + 0.01 * g))
	# Đom đóm lửa bay lên (vẽ cả khi có ảnh nền).
	for e in _embers:
		var life := fposmod(_time * float(e["speed"]) + float(e["phase"]), 1.0)
		var x := (float(e["x"]) + 0.03 * sin(_time * 0.8 + float(e["phase"]) * 9.0)) * w
		var y := h * (1.05 - life * 1.1)
		var col := Color(1.0, 0.62, 0.22) if bool(e["warm"]) else Color(0.5, 0.8, 1.0)
		col.a = sin(life * PI) * 0.8
		_backdrop.draw_circle(Vector2(x, y), float(e["size"]), col)


## Cảnh xa: tia sáng từ trăng, ba lớp núi, lâu đài bóng đen với cửa sổ chập chờn, nền đá có đường hội tụ.
func _draw_landscape(w: float, h: float) -> void:
	var moon := Vector2(w * 0.74, h * 0.38)
	for i in 8:  # tia sáng từ trăng rọi xuống
		var ang := 1.2 + float(i) * 0.12 + sin(_time * 0.2 + float(i)) * 0.02
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var spread := 30.0 + float(i) * 9.0
		var far := h * 0.9
		_backdrop.draw_colored_polygon(PackedVector2Array([moon + perp * 4.0, moon + dir * far + perp * spread, moon + dir * far - perp * spread, moon - perp * 4.0]), Color(0.7, 0.6, 1.0, 0.03))
	var horizon := h * 0.64
	for layer in 3:
		var base := horizon - float(2 - layer) * h * 0.055
		var amp := h * (0.13 - 0.025 * float(layer))
		var pts := PackedVector2Array()
		var step := maxf(w / 56.0, 4.0)
		var x := 0.0
		while x <= w + step:
			var n := 0.5 + 0.28 * sin(x * 0.006 + float(layer) * 2.1) + 0.14 * sin(x * 0.017 + float(layer) * 5.3) + 0.08 * sin(x * 0.041 + float(layer))
			pts.append(Vector2(x, base - amp * n))
			x += step
		pts.append(Vector2(w + step, h))
		pts.append(Vector2(0.0, h))
		var shade := 1.0 - 0.3 * float(layer)
		_backdrop.draw_colored_polygon(pts, Color(0.13, 0.08, 0.24).lerp(Color(0.04, 0.025, 0.09), float(layer) / 2.0) * Color(shade, shade, shade, 1.0))
		if layer == 1:
			_draw_castle(Vector2(w * 0.6, base - amp * 0.62), h)
	# Nền đá phía trước: dải tối + đường hội tụ về chân trời.
	for i in 12:
		var t := float(i) / 11.0
		_backdrop.draw_rect(Rect2(0.0, horizon + (h - horizon) * t, w, (h - horizon) / 11.0 + 1.0), Color(0.07, 0.04, 0.13).lerp(Color(0.02, 0.015, 0.05), t))
	var vanish := Vector2(w * 0.55, horizon)
	for i in 15:
		var bx := w * (-0.4 + 1.8 * float(i) / 14.0)
		_backdrop.draw_line(vanish, Vector2(bx, h), Color(0.55, 0.45, 0.85, 0.07), 1.5)
	for i in 6:
		var ty := horizon + (h - horizon) * pow(float(i + 1) / 6.0, 2.0)
		_backdrop.draw_line(Vector2(0.0, ty), Vector2(w, ty), Color(0.55, 0.45, 0.85, 0.06), 1.5)


func _draw_castle(base: Vector2, h: float) -> void:
	var col := Color(0.035, 0.022, 0.075)
	var u := h * 0.01
	_backdrop.draw_rect(Rect2(base.x - 9.0 * u, base.y - 14.0 * u, 18.0 * u, 16.0 * u), col)  # chính điện
	for i in 6:  # chân tường thành răng cưa
		_backdrop.draw_rect(Rect2(base.x - 9.0 * u + float(i) * 3.2 * u, base.y - 16.0 * u, 1.8 * u, 2.0 * u), col)
	for side in [-1.0, 1.0]:  # hai tháp có mái nhọn
		var tx: float = base.x + side * 11.0 * u
		_backdrop.draw_rect(Rect2(tx - 2.6 * u, base.y - 24.0 * u, 5.2 * u, 26.0 * u), col)
		_backdrop.draw_colored_polygon(PackedVector2Array([Vector2(tx - 3.6 * u, base.y - 24.0 * u), Vector2(tx, base.y - 32.0 * u), Vector2(tx + 3.6 * u, base.y - 24.0 * u)]), col)
	_backdrop.draw_rect(Rect2(base.x - 2.6 * u, base.y - 30.0 * u, 5.2 * u, 17.0 * u), col)  # tháp giữa
	_backdrop.draw_colored_polygon(PackedVector2Array([Vector2(base.x - 3.6 * u, base.y - 30.0 * u), Vector2(base.x, base.y - 40.0 * u), Vector2(base.x + 3.6 * u, base.y - 30.0 * u)]), col)
	var windows := [Vector2(-11.0, -18.0), Vector2(11.0, -18.0), Vector2(0.0, -24.0), Vector2(-5.0, -8.0), Vector2(5.0, -8.0), Vector2(0.0, -10.0)]
	for i in windows.size():
		var flick := 0.6 + 0.4 * sin(_time * (2.0 + float(i) * 0.7) + float(i) * 2.3)
		var wp: Vector2 = windows[i]
		_backdrop.draw_rect(Rect2(base.x + wp.x * u - 0.5 * u, base.y + wp.y * u, 1.0 * u, 1.8 * u), Color(1.0, 0.72, 0.3, 0.5 + 0.4 * flick))


## Đường kẻ trang trí: vạch mờ dần hai phía, hình thoi vàng ở giữa.
func _on_ornament_draw(c: Control) -> void:
	var mid := Vector2(c.size.x * 0.5, c.size.y * 0.5)
	for i in 20:
		var t := float(i) / 20.0
		var a := (1.0 - t) * 0.8
		var seg := (c.size.x * 0.5 - 22.0) / 20.0
		c.draw_line(Vector2(mid.x - 14.0 - seg * float(i), mid.y), Vector2(mid.x - 14.0 - seg * float(i + 1), mid.y), Color(1.0, 0.8, 0.4, a), 2.0)
		c.draw_line(Vector2(mid.x + 14.0 + seg * float(i), mid.y), Vector2(mid.x + 14.0 + seg * float(i + 1), mid.y), Color(1.0, 0.8, 0.4, a), 2.0)
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -8), mid + Vector2(10, 0), mid + Vector2(0, 8), mid + Vector2(-10, 0)]), Color(1.0, 0.82, 0.42))
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -4), mid + Vector2(5, 0), mid + Vector2(0, 4), mid + Vector2(-5, 0)]), Color(0.35, 0.15, 0.6))


## Lớp phủ trước nhân vật: sương dưới chân, tối dần về góc, và một dải tối bên trái để chữ/menu luôn dễ đọc.
func _on_front_draw(front: Control) -> void:
	var w := front.size.x
	var h := front.size.y
	for i in 10:
		var t := float(i) / 9.0
		front.draw_rect(Rect2(0.0, h * (0.78 + 0.22 * t), w, h * 0.22 / 9.0 + 1.0), Color(0.12, 0.08, 0.2, 0.05 + 0.4 * t * t))
	for i in 14:  # dải tối bên trái
		var t := float(i) / 13.0
		front.draw_rect(Rect2(w * 0.5 * t * 0.9, 0.0, w * 0.5 / 13.0 * 0.9 + 1.0, h), Color(0.02, 0.01, 0.05, 0.62 * (1.0 - t) * (1.0 - t)))
	for i in 8:  # tối góc trên
		var t := float(i) / 7.0
		front.draw_rect(Rect2(0.0, h * 0.12 * t, w, h * 0.12 / 7.0 + 1.0), Color(0.0, 0.0, 0.03, 0.4 * (1.0 - t)))


# ---------------------------------------------------------------- Nút
func _on_continue_pressed() -> void:
	if _busy:
		return
	_busy = true
	SaveSystem.continue_requested = true  # Main nạp file lưu và vào thẳng sảnh chờ (bỏ qua cutscene)
	_enter_game()


func _on_start_pressed() -> void:
	if _busy or _overlay != null:
		return
	_open_name_prompt()


func _on_fame_pressed() -> void:
	if _busy or _overlay != null:
		return
	_overlay = _make_overlay()
	var view := HallOfFameView.new()
	view.limit = 25
	view.custom_minimum_size = Vector2(1060.0, 0.0)
	_overlay.get_meta("box").add_child(view)
	var close := Button.new()
	close.text = "ĐÓNG (Esc)"
	close.custom_minimum_size = Vector2(200.0, 44.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.apply_button(close, 12, 16)
	close.pressed.connect(_close_overlay)
	_overlay.get_meta("box").add_child(close)


## Lớp phủ tối full màn hình, trả về Control gốc; meta "box" = VBoxContainer ở giữa để thêm nội dung.
func _make_overlay() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.0, 0.04, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	root.set_meta("box", box)
	return root


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_name_edit = null


## Bảng "xưng danh": bắt buộc nhập tên (tối đa RunStats.MAX_NAME_LENGTH ký tự) trước khi vào cutscene.
func _open_name_prompt() -> void:
	_overlay = _make_overlay()
	var box: VBoxContainer = _overlay.get_meta("box")
	var panel := PanelContainer.new()
	UIStyle.apply_panel(panel, 18, 26.0)
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	panel.add_child(inner)
	var title := Label.new()
	title.text = "XƯNG DANH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(title, 34, 6, UIStyle.ACCENT)
	inner.add_child(title)
	var prompt := Label.new()
	prompt.text = "Lữ khách, hãy cho biết tên của ngươi:"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(prompt, 17, 3, Color(0.85, 0.88, 1.0))
	inner.add_child(prompt)
	_name_edit = LineEdit.new()
	_name_edit.max_length = RunStats.MAX_NAME_LENGTH
	_name_edit.placeholder_text = "Tên của bạn"
	_name_edit.text = "" if RunStats.player_name == RunStats.DEFAULT_NAME else RunStats.player_name
	_name_edit.custom_minimum_size = Vector2(360.0, 46.0)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text_changed.connect(func(_t: String) -> void: SfxPlayer.play_sfx(&"type", -6.0))
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_name())
	inner.add_child(_name_edit)
	_name_error = Label.new()
	_name_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_name_error, 14, 3, Color(1.0, 0.45, 0.4))
	inner.add_child(_name_error)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	inner.add_child(row)
	var ok := Button.new()
	ok.text = "BẮT ĐẦU"
	ok.custom_minimum_size = Vector2(170.0, 44.0)
	UIStyle.apply_button(ok, 12, 17)
	ok.pressed.connect(_confirm_name)
	row.add_child(ok)
	var cancel := Button.new()
	cancel.text = "HỦY (Esc)"
	cancel.custom_minimum_size = Vector2(150.0, 44.0)
	UIStyle.apply_button(cancel, 12, 15)
	cancel.pressed.connect(_close_overlay)
	row.add_child(cancel)
	_name_edit.grab_focus.call_deferred()


func _confirm_name() -> void:
	if _name_edit == null:
		return
	if _name_edit.text.strip_edges().is_empty():
		_name_error.text = "Hãy nhập tên trước khi bắt đầu."
		return
	RunStats.set_player_name(_name_edit.text)
	_close_overlay()
	_start_new_game()


func _start_new_game() -> void:
	if _busy:
		return
	_busy = true
	SaveSystem.continue_requested = false
	var scene: PackedScene = cutscene_scene
	var cutscene: Node = scene.instantiate() if scene != null else IntroCutscene.new()
	if cutscene.has_signal("finished"):
		cutscene.connect("finished", _enter_game, CONNECT_ONE_SHOT)
	else:
		push_warning("MainMenu: cutscene không có signal 'finished' (nên extends CutsceneBase), vào game ngay.")
		cutscene.queue_free()
		_enter_game()
		return
	_menu_root.visible = false
	add_child(cutscene)


func _enter_game() -> void:
	if game_scene_path.is_empty() or not ResourceLoader.exists(game_scene_path):
		push_error("MainMenu: không tìm thấy game_scene_path '%s'." % game_scene_path)
		_busy = false
		_menu_root.visible = true
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	await tween.finished
	get_tree().change_scene_to_file(game_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
