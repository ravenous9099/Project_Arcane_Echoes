class_name CombatHUD
extends CanvasLayer
## Giao diện chiến đấu gọn, bo góc:
##  - Dưới giữa: thanh máu Player (viên thuốc) nằm trên hàng 4 ô Spell + ô Dash có lớp phủ hồi chiêu.
##  - Trên phải: BẢNG ĐIỂM (điểm, tiến độ tới cổng Boss, số hạ gục theo loại Enemy).
##  - Trên trái: nút Tạm dừng và nút bật/tắt "chữ debug" (nhãn chữ cũ do Main quản lý).
##  - Thanh máu Boss, thông báo ngắn (toast), viền đỏ khi máu thấp/trúng đòn, màn hình chết, màn che chuyển cảnh.
## Dựng hoàn toàn bằng code; toạ độ theo kích thước gốc 1152x648 (stretch canvas_items nên tự co giãn).
## Số sát thương và thanh máu Enemy nằm trong thế giới (CombatFx, EnemyHealthBar), không nằm ở đây.
## Mọi Control không phải nút đều đặt mouse_filter = IGNORE để click xuyên xuống (Player dùng chuột trái để bắn).

## Người chơi bấm "Chơi lại" ở màn hình chết.
signal restart_requested
## Người chơi bấm nút tạm dừng trên HUD.
signal pause_requested
## Chữ debug được bật/tắt (true = đang hiện).
signal debug_text_toggled(is_visible: bool)

const SPELL_ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4"]
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 0.85);
	float a = smoothstep(0.35, 0.8, length(p)) * intensity;
	COLOR = vec4(0.85, 0.05, 0.08, a);
}
"""

## Máu từ mức này trở xuống (tỉ lệ 0..1) thì bật cảnh báo máu thấp.
@export_range(0.05, 0.9, 0.05) var low_health_threshold: float = 0.3
@export var slot_size: Vector2 = Vector2(42, 42)
@export var slot_gap: int = 5
## Hiện chữ debug cũ khi bắt đầu game.
@export var debug_text_visible: bool = false

var _player: Node = null
var _boss: Node = null  # Boss đầu tiên trong danh sách thanh máu (get_boss)
## Các thanh máu Boss đang hiện (tối đa MAX_BOSS_BARS), mỗi phần tử: {boss, root, name, bar}.
var _boss_entries: Array[Dictionary] = []
const MAX_BOSS_BARS: int = 3
var _tracker: ScoreTracker = null
var _root: Control
var _hp_bar: PixelBar
var _name_label: Label
var _death_rank: Label
var _mana_bar: PixelBar
var _slots: Array[CooldownSlot] = []
var _dash_slot: CooldownSlot
var _vignette: ColorRect
var _vignette_material: ShaderMaterial
var _debug_button: Button
var _score_value: Label
var _score_bar: PixelBar
var _score_status: Label
var _score_rows: Label
var _boss_box: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _banner_box: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _score_title: Label
var _death_layer: Control
var _death_stats: Label
var _fade: ColorRect
var _pointer: PortalPointer

var _icon_cache: Dictionary = {}
var _minimap: MiniMap = null
var _score_panel: Control = null
var _combo_panel: ComboPanel = null
var _gold_counter: GoldCounter = null
var _running: bool = false
var _run_time: float = 0.0
var _time: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh_debug_button()
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)


# ---------------------------------------------------------------- API
func bind_player(player: Node) -> void:
	_player = player
	_pointer.player = player as Node2D
	if player != null and player.has_signal("damaged") and not player.is_connected("damaged", _on_player_damaged):
		player.connect("damaged", _on_player_damaged)


## Gắn bảng điểm: HUD tự cập nhật điểm, tiến độ tới cổng Boss và số hạ gục theo loại.
func bind_score_tracker(tracker: ScoreTracker) -> void:
	_tracker = tracker
	tracker.score_changed.connect(_on_score_changed)
	_on_score_changed(tracker.score, tracker.score_goal)


## Gắn cổng Boss để HUD vẽ mũi tên chỉ hướng khi cổng đã mở.
func set_portal(portal: BossPortal) -> void:
	_pointer.portal = portal


func get_run_time() -> float:
	return _run_time


func is_debug_text_visible() -> bool:
	return debug_text_visible


## Bật/tắt nhãn chữ debug cũ. Main nghe signal debug_text_toggled để ẩn/hiện nhãn.
func set_debug_text_visible(value: bool) -> void:
	debug_text_visible = value
	_refresh_debug_button()
	debug_text_toggled.emit(debug_text_visible)


func toggle_debug_text() -> void:
	set_debug_text_visible(not debug_text_visible)


## Hiện thanh máu Boss ở giữa phía trên màn hình. boss cần có health, max_health, signal died.
## Hiện MỘT thanh máu Boss (xóa các thanh cũ). Dùng cho phòng Boss thường và Boss thử nghiệm.
func show_boss_bar(boss: Node, title: String) -> void:
	hide_boss_bar()
	add_boss_bar(boss, title)


## Thêm một thanh máu Boss (tối đa 3, xếp ngang cạnh nhau - dùng ở Level 4 khi nhiều Boss cùng xuất hiện).
## Thanh tự biến mất khi Boss đó chết.
func add_boss_bar(boss: Node, title: String) -> void:
	if boss == null or not is_instance_valid(boss) or _boss_entries.size() >= MAX_BOSS_BARS:
		return
	for entry in _boss_entries:
		if entry["boss"] == boss:
			return
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	_ignore(root)
	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(name_label, 15, 5)
	_ignore(name_label)
	root.add_child(name_label)
	var bar := PixelBar.new()
	bar.fill_color = Color(0.7, 0.2, 0.85)
	bar.low_fill_color = Color(1.0, 0.35, 0.5)
	root.add_child(bar)
	_boss_box.add_child(root)
	_boss_entries.append({"boss": boss, "root": root, "name": name_label, "bar": bar})
	if boss.has_signal("died"):
		boss.connect("died", _on_boss_died)
	_boss = _boss_entries[0]["boss"]
	_relayout_boss_bars()


## Gỡ thanh máu của một Boss (đã chết hoặc bị xóa).
func remove_boss_bar(boss: Node) -> void:
	for i in range(_boss_entries.size() - 1, -1, -1):
		var entry := _boss_entries[i]
		if entry["boss"] == boss:
			if is_instance_valid(boss) and boss.has_signal("died") and boss.is_connected("died", _on_boss_died):
				boss.disconnect("died", _on_boss_died)
			(entry["root"] as Node).queue_free()
			_boss_entries.remove_at(i)
	_boss = _boss_entries[0]["boss"] if not _boss_entries.is_empty() else null
	_relayout_boss_bars()


func get_boss() -> Node:
	return _boss


func hide_boss_bar() -> void:
	for entry in _boss_entries:
		var b: Node = entry["boss"]
		if is_instance_valid(b) and b.has_signal("died") and b.is_connected("died", _on_boss_died):
			b.disconnect("died", _on_boss_died)
		(entry["root"] as Node).queue_free()
	_boss_entries.clear()
	_boss = null
	if _boss_box != null:
		_boss_box.visible = false


## 1 Boss: thanh rộng 400 px; 2 Boss: 2 x 300; 3 Boss: 3 x 270 (xếp ngang giữa mép trên màn hình).
func _relayout_boss_bars() -> void:
	if _boss_box == null:
		return
	_boss_box.visible = not _boss_entries.is_empty()
	var width := 400.0 if _boss_entries.size() <= 1 else (300.0 if _boss_entries.size() == 2 else 270.0)
	for entry in _boss_entries:
		(entry["bar"] as Control).custom_minimum_size = Vector2(width, 14.0 if _boss_entries.size() > 1 else 16.0)
		(entry["root"] as Control).custom_minimum_size = Vector2(width, 0.0)


## Thông báo ngắn ở giữa phía trên (tự mờ đi sau seconds giây).
func show_toast(text: String, seconds: float = 2.5) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast_panel.visible = false)


## Biểu ngữ lớn giữa màn hình (tên Boss, đổi giai đoạn, chiến thắng). Tự mờ đi sau seconds giây.
func show_banner(title: String, subtitle: String = "", seconds: float = 2.5) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_sub.visible = not subtitle.is_empty()
	_banner_box.visible = true
	_banner_box.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(func() -> void: _banner_box.visible = false)


## Tiêu đề bảng điểm theo level, ví dụ "LEVEL 2" hoặc "LEVEL 1 (VÒNG 2)".
func set_level_title(text: String) -> void:
	_score_title.text = "%s  -  ĐIỂM" % text


## Số vòng chơi hiện ở tiêu đề bảng điểm (vòng 1 không hiện). Dùng set_level_title() khi có hệ thống Level.
func set_round(round_number: int) -> void:
	_score_title.text = "VÒNG %d  -  ĐIỂM" % round_number if round_number > 1 else "ĐIỂM"


## Làm tối/sáng toàn màn hình (chuyển cảnh). Dùng: await hud.fade_to(1.0, 0.4)
func fade_to(alpha: float, duration: float = 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished


# ---------------------------------------------------------------- Dựng giao diện
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_vignette()
	_pointer = PortalPointer.new()
	_pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_pointer)
	_build_bottom_cluster()
	_build_minimap()
	_build_score_panel()
	_build_combo_and_gold()
	_build_top_left_buttons()
	_build_boss_bar()
	_build_toast()
	_build_banner()
	_build_death_screen()

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)


func _ignore(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


func _build_vignette() -> void:
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = _vignette_material
	_vignette.visible = false
	_root.add_child(_vignette)


## Cụm giữa đáy màn hình: máu Player ở trên, hàng ô kỹ năng ở dưới, cùng một chiều rộng.
func _build_bottom_cluster() -> void:
	var cluster := VBoxContainer.new()
	cluster.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cluster.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cluster.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cluster.offset_bottom = -10.0
	cluster.add_theme_constant_override("separation", 5)
	_ignore(cluster)
	_root.add_child(cluster)

	var bar_width := slot_size.x * 5.0 + slot_gap * 5.0 + 10.0
	# Tên người chơi (nhập ở menu chính) nằm ngay trên thanh máu.
	_name_label = Label.new()
	_name_label.text = RunStats.player_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.apply_label(_name_label, 16, 5, Color(1.0, 0.92, 0.6))
	_ignore(_name_label)
	cluster.add_child(_name_label)
	RunStats.stats_changed.connect(func() -> void: _name_label.text = RunStats.player_name)
	_hp_bar = PixelBar.new()
	_hp_bar.custom_minimum_size = Vector2(bar_width, 14)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cluster.add_child(_hp_bar)

	# Thanh mana của Ultimate: ẩn cho tới khi người chơi nhặt được Ultimate.
	_mana_bar = PixelBar.new()
	_mana_bar.custom_minimum_size = Vector2(bar_width, 12)
	_mana_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mana_bar.low_threshold = 0.0
	_mana_bar.fill_color = Color(0.3, 0.55, 1.0)
	_mana_bar.chip_color = Color(0.7, 0.85, 1.0)
	_mana_bar.chip_speed = 3.0
	_mana_bar.visible = false
	cluster.add_child(_mana_bar)

	var hotbar := HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", slot_gap)
	_ignore(hotbar)
	cluster.add_child(hotbar)
	for i in SPELL_ACTIONS.size():
		var slot := CooldownSlot.new()
		slot.mode = CooldownSlot.Mode.SPELL
		slot.custom_minimum_size = slot_size
		slot.key_text = _action_key_text(SPELL_ACTIONS[i])
		hotbar.add_child(slot)
		_slots.append(slot)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	_ignore(gap)
	hotbar.add_child(gap)
	_dash_slot = CooldownSlot.new()
	_dash_slot.mode = CooldownSlot.Mode.DASH
	_dash_slot.custom_minimum_size = slot_size
	_dash_slot.key_text = _action_key_text(&"dash")
	hotbar.add_child(_dash_slot)


## Mini map ở góc trên cùng bên phải (bảng điểm nằm ngay dưới).
func _build_minimap() -> void:
	_minimap = MiniMap.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_minimap.offset_top = 14.0
	_minimap.offset_right = -14.0
	_minimap.offset_left = -14.0 - _minimap.custom_minimum_size.x
	_minimap.offset_bottom = 14.0 + _minimap.custom_minimum_size.y
	_root.add_child(_minimap)


## Main gọi mỗi khi map mới sẵn sàng: mini map dựng lại hình thu nhỏ và theo dõi Player.
func set_minimap_source(world: MapGenerator, player: Node2D) -> void:
	if _minimap != null:
		_minimap.set_source(world, player)


## Bộ đếm combo (góc trái, dưới nút pause) và số vàng (góc dưới phải).
func _build_combo_and_gold() -> void:
	_combo_panel = ComboPanel.new()
	_combo_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)  # góc trái, ngay dưới nút pause
	_combo_panel.offset_left = 12.0
	_combo_panel.offset_top = 48.0
	_combo_panel.offset_right = 12.0 + _combo_panel.custom_minimum_size.x
	_combo_panel.offset_bottom = 48.0 + _combo_panel.custom_minimum_size.y
	_root.add_child(_combo_panel)
	_gold_counter = GoldCounter.new()
	_gold_counter.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_gold_counter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_gold_counter.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_gold_counter.offset_right = -14.0
	_gold_counter.offset_bottom = -14.0
	_gold_counter.offset_left = -14.0 - _gold_counter.custom_minimum_size.x
	_gold_counter.offset_top = -14.0 - _gold_counter.custom_minimum_size.y
	_root.add_child(_gold_counter)


## Ở sảnh chờ: ẩn mini map, bảng điểm và combo (không có chiến đấu); số vàng vẫn hiện.
func set_hub_mode(in_hub: bool) -> void:
	if _minimap != null:
		_minimap.visible = not in_hub
	if _score_panel != null:
		_score_panel.visible = not in_hub
	if _combo_panel != null:
		_combo_panel.visible = not in_hub


## Bảng điểm ở góc trên phải.
func _build_score_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = 14.0 + 150.0 + 12.0  # dưới mini map
	panel.offset_right = -10.0
	panel.custom_minimum_size = Vector2(190, 0)
	UIStyle.apply_panel(panel, 14, 9.0)
	_ignore(panel)
	_root.add_child(panel)
	_score_panel = panel

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_ignore(box)
	panel.add_child(box)

	var head := HBoxContainer.new()
	_ignore(head)
	box.add_child(head)
	var title := Label.new()
	title.text = "ĐIỂM"
	_score_title = title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.apply_label(title, 12, 3, Color(0.85, 0.8, 0.7))
	_ignore(title)
	head.add_child(title)
	_score_value = Label.new()
	_score_value.text = "0"
	UIStyle.apply_label(_score_value, 18, 4, UIStyle.ACCENT)
	_ignore(_score_value)
	head.add_child(_score_value)

	_score_bar = PixelBar.new()
	_score_bar.custom_minimum_size = Vector2(0, 10)
	_score_bar.show_text = false
	_score_bar.low_threshold = 0.0
	_score_bar.chip_speed = 3.0
	_score_bar.fill_color = Color(1.0, 0.78, 0.25)
	_score_bar.chip_color = Color(1.0, 0.95, 0.7)
	box.add_child(_score_bar)

	_score_status = Label.new()
	UIStyle.apply_label(_score_status, 11, 3, Color(0.9, 0.88, 0.8))
	_ignore(_score_status)
	box.add_child(_score_status)

	_score_rows = Label.new()
	UIStyle.apply_label(_score_rows, 11, 3, Color(0.8, 0.8, 0.85))
	_ignore(_score_rows)
	box.add_child(_score_rows)


func _build_top_left_buttons() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(10, 10)
	row.add_theme_constant_override("separation", 6)
	_ignore(row)
	_root.add_child(row)

	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.custom_minimum_size = Vector2(30, 28)
	pause_button.tooltip_text = "Tạm dừng (Esc)"
	UIStyle.apply_button(pause_button, 14, 12)
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	row.add_child(pause_button)

	_debug_button = Button.new()
	_debug_button.custom_minimum_size = Vector2(66, 28)
	_debug_button.tooltip_text = "Bật/tắt chữ debug"
	UIStyle.apply_button(_debug_button, 14, 12)
	_debug_button.pressed.connect(toggle_debug_text)
	row.add_child(_debug_button)


func _build_boss_bar() -> void:
	var box := HBoxContainer.new()  # các thanh máu Boss xếp ngang, căn giữa
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -440.0
	box.offset_right = 440.0
	box.offset_top = 12.0
	box.offset_bottom = 60.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.visible = false
	_ignore(box)
	_root.add_child(box)
	_boss_box = box


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.offset_top = 70.0
	UIStyle.apply_panel(_toast_panel, 16, 10.0)
	_toast_panel.visible = false
	_ignore(_toast_panel)
	_root.add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_toast_label, 16, 4, UIStyle.ACCENT)
	_ignore(_toast_label)
	_toast_panel.add_child(_toast_label)


func _build_banner() -> void:
	_banner_box = VBoxContainer.new()
	_banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_box.offset_top = 140.0
	_banner_box.add_theme_constant_override("separation", 4)
	_banner_box.visible = false
	_ignore(_banner_box)
	_root.add_child(_banner_box)
	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_banner_title, 38, 9, Color(1.0, 0.85, 0.4))
	_ignore(_banner_title)
	_banner_box.add_child(_banner_title)
	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_banner_sub, 16, 5, Color(0.95, 0.92, 0.85))
	_ignore(_banner_sub)
	_banner_box.add_child(_banner_sub)


func _build_death_screen() -> void:
	_death_layer = Control.new()
	_death_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_layer.mouse_filter = Control.MOUSE_FILTER_STOP  # chặn bấm xuyên xuống game
	_death_layer.visible = false
	_root.add_child(_death_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	_ignore(dim)
	_death_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ignore(center)
	_death_layer.add_child(center)
	var panel := PanelContainer.new()
	UIStyle.apply_panel(panel, 20, 22.0)
	_ignore(panel)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_ignore(box)
	panel.add_child(box)

	var title := Label.new()
	title.text = "BẠN ĐÃ CHẾT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(title, 40, 8, Color(1.0, 0.3, 0.3))
	_ignore(title)
	box.add_child(title)

	_death_stats = Label.new()
	_death_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_death_stats, 16, 4)
	_ignore(_death_stats)
	box.add_child(_death_stats)

	_death_rank = Label.new()
	_death_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_death_rank, 18, 4, Color(1.0, 0.9, 0.5))
	_ignore(_death_rank)
	box.add_child(_death_rank)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	_ignore(buttons)
	box.add_child(buttons)
	# Hai lựa chọn: chơi lại NGAY với tên cũ, hoặc về menu chính để bấm "Chơi mới" và đặt tên mới.
	var again := Button.new()
	again.text = "Chơi lại - giữ tên (Enter)"
	again.custom_minimum_size = Vector2(250, 40)
	UIStyle.apply_button(again, 16, 16)
	again.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(again)
	var to_menu := Button.new()
	to_menu.text = "Về menu chính"
	to_menu.custom_minimum_size = Vector2(200, 40)
	UIStyle.apply_button(to_menu, 16, 16)
	to_menu.pressed.connect(_go_to_main_menu)
	buttons.add_child(to_menu)


## Về menu chính từ màn hình chết (bỏ lượt hiện tại; lượt đã được ghi Hall of Fame khi chết).
func _go_to_main_menu() -> void:
	const MENU_PATH := "res://Scenes/UI/MainMenu.tscn"
	get_tree().paused = false
	GameManager.is_run_active = false
	SpellSystem.reset()
	get_tree().change_scene_to_file(MENU_PATH)


# ---------------------------------------------------------------- Cập nhật mỗi frame
func _process(delta: float) -> void:
	_time += delta
	_hit_flash = maxf(_hit_flash - delta * 2.5, 0.0)
	if _running:
		_run_time += delta
	_update_player_widgets()
	_update_boss()


func _update_player_widgets() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var health := float(_player.get("health"))
	var max_health := float(_player.get("max_health"))
	var dead := bool(_player.get("is_dead"))
	_hp_bar.set_values(health, max_health)
	_hp_bar.low_threshold = low_health_threshold

	var mana := _player.get("mana") as ManaPool
	var mana_full := mana != null and mana.is_full()
	_mana_bar.visible = mana != null and mana.is_unlocked()
	if _mana_bar.visible:
		_mana_bar.set_values(mana.value, mana.get_max())
		_mana_bar.fill_color = Color(1.0, 0.8, 0.25) if mana_full else Color(0.3, 0.55, 1.0)
		_mana_bar.custom_text = "ULTIMATE SẴN SÀNG - bấm R" if mana_full else "MANA %d / %d" % [int(mana.value), int(mana.get_max())]
	for i in _slots.size():
		var spell := SpellSystem.get_equipped(i)
		_slots[i].powered = mana_full and i == SpellSystem.ULTIMATE_SLOT
		_slots[i].refresh_spell(spell, _icon_for(spell), SpellSystem.get_cooldown_ratio(spell), SpellSystem.get_cooldown_remaining(spell), not dead)
	if _player.has_method("get_dash_charges"):
		var charges: int = _player.call("get_dash_charges")
		var max_charges := int(_player.get("dash_max_charges"))
		var left: float = _player.call("get_dash_cooldown_remaining")
		var ratio: float = _player.call("get_dash_cooldown_ratio")
		_dash_slot.refresh_dash(ratio, left, charges, max_charges, not dead)

	# Viền đỏ: nhấp nháy khi máu thấp, loé lên khi vừa trúng đòn
	var intensity := _hit_flash * 0.55
	if not dead and health > 0.0 and health / maxf(max_health, 0.001) <= low_health_threshold:
		intensity = maxf(intensity, 0.35 + 0.12 * sin(_time * 6.0))
	_vignette_material.set_shader_parameter("intensity", intensity)
	_vignette.visible = intensity > 0.01


func _update_boss() -> void:
	for i in range(_boss_entries.size() - 1, -1, -1):
		var entry := _boss_entries[i]
		var b: Node = entry["boss"]
		if not is_instance_valid(b):
			remove_boss_bar(b)
			continue
		(entry["bar"] as PixelBar).set_values(float(b.get("health")), float(b.get("max_health")))


# ---------------------------------------------------------------- Sự kiện
func _on_player_damaged(_amount: float, _health_left: float) -> void:
	_hit_flash = 1.0


func _on_score_changed(score: int, goal: int) -> void:
	_score_value.text = str(score)
	var base := _tracker.goal_base if _tracker != null else 0
	_score_bar.set_values(float(clampi(score - base, 0, maxi(goal - base, 1))), float(maxi(goal - base, 1)))
	if _tracker != null and _tracker.goal_unlocked:
		_score_status.text = "Cổng Boss: ĐÃ MỞ"
		_score_status.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7))
	else:
		_score_status.text = "Cổng Boss: %d / %d" % [score, goal]
		_score_status.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	_score_rows.text = _breakdown_text()


## Mỗi dòng: "Hiệp sĩ x3 ..... 30".
func _breakdown_text() -> String:
	if _tracker == null:
		return ""
	var lines := PackedStringArray()
	for row in _tracker.get_breakdown():
		lines.append("%s x%d  +%d" % [row["name"], row["count"], row["points"]])
	return "\n".join(lines)


func _on_boss_died(boss_node: Node = null) -> void:
	remove_boss_bar(boss_node)


func _on_run_started() -> void:
	_running = true
	_run_time = 0.0
	_hit_flash = 0.0
	_death_layer.visible = false
	hide_boss_bar()


func _on_run_ended(reason: StringName) -> void:
	_running = false
	if reason != &"player_died":
		return  # chỉ hiện màn hình chết khi thật sự do Player chết
	var score := _tracker.score if _tracker != null else 0
	var kills := _tracker.total_kills if _tracker != null else 0
	_death_stats.text = "%s\nThời gian sống: %s\nĐiểm: %d   |   Hạ gục: %d   |   Sát thương: %d\nSpell thu thập: %d   |   Đã dùng spell: %d lần" % [RunStats.player_name, format_time(RunStats.survival_time), score, kills, int(RunStats.damage_dealt), SpellSystem.get_collected_count(), RunStats.spells_cast]
	_death_rank.text = ""
	_death_layer.modulate.a = 0.0
	_death_layer.visible = true
	create_tween().tween_property(_death_layer, "modulate:a", 1.0, 0.4)


## Main gọi sau khi ghi Hall of Fame: hiện hạng ở màn hình chết.
func set_death_rank_text(text: String) -> void:
	if _death_rank != null:
		_death_rank.text = text


func _refresh_debug_button() -> void:
	if _debug_button != null:
		_debug_button.text = "Chữ: Bật" if debug_text_visible else "Chữ: Tắt"


# ---------------------------------------------------------------- Hàm phụ
static func format_time(seconds: float) -> String:
	var total := int(seconds)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [total / 60, total % 60]


## Biểu tượng spell: SpellData.icon -> khung signature (icon_folder + icon_frame) -> khung giữa của VFX (xem VfxFrames.icon_for).
## Trả về null nếu không có ảnh nào, khi đó ô sẽ vẽ viên ngọc bằng code.
func _icon_for(spell: SpellData) -> Texture2D:
	if spell == null:
		return null
	if _icon_cache.has(spell.id):
		return _icon_cache[spell.id] as Texture2D
	var icon: Texture2D = VfxFrames.icon_for(spell)
	_icon_cache[spell.id] = icon
	return icon


## Chữ phím cho nhãn ô: lấy từ Input Map để luôn đúng với phím đang gán.
func _action_key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
				MOUSE_BUTTON_MIDDLE:
					return "MMB"
	return ""
