class_name InventoryPanel
extends CanvasLayer
## Bảng TRANG BỊ (phím Tab), trang ngang chia 2 nhóm: KỸ NĂNG (spell đang sở hữu + 4 ô chuột trái, Q, E, R) và TRANG BỊ SỞ HỮU (relic đã mua + chỉ số).
## Cách dùng: trỏ chuột vào biểu tượng spell, giữ chuột trái và KÉO thả vào một ô kỹ năng để trang bị
## (nếu spell đang ở ô khác thì hai ô đổi chỗ). Kéo một ô kỹ năng sang ô khác để đổi chỗ, hoặc kéo về danh sách kho để tháo.
## Ô R dành riêng cho Ultimate (khóa). Mở bảng thì game tạm dừng (đạn và cooldown đứng yên); Tab hoặc Esc để đóng.
## Xây hoàn toàn bằng code; Main thêm node này là đủ (Main.setup_inventory).

signal opened
signal closed

const SLOT_KEYS: Array[String] = ["CHUỘT TRÁI", "Q", "E", "R"]
const SHORT_KEYS: Array[String] = ["LMB", "Q", "E", "R"]

var is_open: bool = false

var _root: Control
var _list_box: HBoxContainer
var _relic_box: HFlowContainer
var _relic_count: Label
var _stats_label: Label
var _zone: SpellTile
var _slot_tiles: Array[SpellTile] = []
var _detail_name: Label
var _detail_text: Label
var _empty_label: Label


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	SpellSystem.inventory_changed.connect(_refresh)
	RelicSystem.relics_changed.connect(_refresh)
	SpellSystem.ultimate_acquired.connect(func(_s: SpellData) -> void: _refresh())


## Phím Tab / Esc. Dùng _input để chạy TRƯỚC PauseMenu (Esc khi bảng mở chỉ đóng bảng).
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_TAB:
		if is_open:
			close()
		elif GameManager.is_run_active and not get_tree().paused:
			open()
		else:
			return
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and is_open:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	_refresh()
	_root.visible = true
	get_tree().paused = true
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	closed.emit()


# ---------------------------------------------------------------- Dựng giao diện
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.03, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	UIStyle.apply_panel(panel, 18, 18.0)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "TRANG BỊ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(title, 24, 5, UIStyle.ACCENT)
	outer.add_child(title)

	# Trang ngang: hai nhóm cạnh nhau.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	outer.add_child(columns)
	columns.add_child(_build_skill_group())
	columns.add_child(VSeparator.new())
	columns.add_child(_build_relic_group())

	_detail_name = Label.new()
	UIStyle.apply_label(_detail_name, 16, 4, UIStyle.ACCENT)
	outer.add_child(_detail_name)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(900, 40)
	UIStyle.apply_label(_detail_text, 13, 3, Color(0.85, 0.85, 0.92))
	outer.add_child(_detail_text)

	var hint := Label.new()
	hint.text = "Kéo biểu tượng spell thả vào ô kỹ năng  •  Kéo ô ra khu \"Spell sở hữu\" để tháo  •  Tab / Esc: đóng"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(hint, 12, 3, Color(0.65, 0.68, 0.8))
	outer.add_child(hint)


## Nhóm 1: KỸ NĂNG = hàng spell đang sở hữu (kéo đi được) + 4 ô kỹ năng (nhận thả).
func _build_skill_group() -> Control:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	group.custom_minimum_size = Vector2(500.0, 0.0)
	var head := Label.new()
	head.text = "KỸ NĂNG"
	UIStyle.apply_label(head, 17, 4, Color(0.95, 0.85, 0.55))
	group.add_child(head)

	var owned_title := Label.new()
	owned_title.text = "Spell đang sở hữu"
	UIStyle.apply_label(owned_title, 13, 3, Color(0.8, 0.8, 0.9))
	group.add_child(owned_title)
	_zone = SpellTile.new(SpellTile.Role.ZONE, Vector2(500, 112))
	_zone.dropped.connect(_on_dropped)
	group.add_child(_zone)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 8.0
	scroll.offset_top = 6.0
	scroll.offset_right = -8.0
	scroll.offset_bottom = -6.0
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_zone.add_child(scroll)
	_list_box = HBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 10)
	_list_box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_list_box)

	var slots_title := Label.new()
	slots_title.text = "Ô kỹ năng"
	UIStyle.apply_label(slots_title, 13, 3, Color(0.8, 0.8, 0.9))
	group.add_child(slots_title)
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 14)
	group.add_child(slot_row)
	for i in SpellSystem.SLOT_COUNT:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 3)
		slot_row.add_child(cell)
		var tile := SpellTile.new(SpellTile.Role.SLOT, Vector2(80, 80))
		tile.slot_index = i
		tile.key_text = SHORT_KEYS[i]
		tile.locked = i == SpellSystem.ULTIMATE_SLOT
		tile.dropped.connect(_on_dropped)
		tile.hovered.connect(_on_tile_hovered)
		cell.add_child(tile)
		_slot_tiles.append(tile)
		var key_label := Label.new()
		key_label.text = SLOT_KEYS[i]
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.apply_label(key_label, 12, 3, Color(0.95, 0.9, 0.75))
		cell.add_child(key_label)
	return group


## Nhóm 2: TRANG BỊ SỞ HỮU = các relic đã mua (trỏ chuột để xem hiệu ứng) + tổng hợp chỉ số.
func _build_relic_group() -> Control:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	group.custom_minimum_size = Vector2(430.0, 0.0)
	var head := Label.new()
	head.text = "TRANG BỊ SỞ HỮU"
	UIStyle.apply_label(head, 17, 4, Color(0.95, 0.85, 0.55))
	group.add_child(head)
	_relic_count = Label.new()
	UIStyle.apply_label(_relic_count, 13, 3, Color(0.8, 0.8, 0.9))
	group.add_child(_relic_count)
	_relic_box = HFlowContainer.new()
	_relic_box.add_theme_constant_override("h_separation", 10)
	_relic_box.add_theme_constant_override("v_separation", 10)
	_relic_box.custom_minimum_size = Vector2(430.0, 112.0)
	group.add_child(_relic_box)
	var stats_title := Label.new()
	stats_title.text = "Chỉ số hiện tại"
	UIStyle.apply_label(stats_title, 13, 3, Color(0.8, 0.8, 0.9))
	group.add_child(stats_title)
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size = Vector2(430.0, 80.0)
	UIStyle.apply_label(_stats_label, 13, 3, Color(0.9, 0.9, 0.85))
	group.add_child(_stats_label)
	return group


# ---------------------------------------------------------------- Cập nhật nội dung
func _refresh() -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		child.queue_free()
		_list_box.remove_child(child)
	var spells := SpellSystem.get_collected_spells()
	if SpellSystem.has_ultimate():
		spells.append(SpellSystem.get_ultimate())
	if spells.is_empty():
		_empty_label = Label.new()
		_empty_label.text = "Chưa có spell nào. Nhặt biểu tượng spell trên map hoặc phần thưởng sau Boss."
		_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_list_box.add_child(_empty_label)
	for spell in spells:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		_list_box.add_child(cell)
		var tile := SpellTile.new(SpellTile.Role.ITEM, Vector2(64, 64))
		tile.refresh(spell)
		tile.locked = spell.fixed_slot >= 0  # Ultimate nằm cố định ở ô R
		var slot := SpellSystem.get_slot_of(spell.id)
		if spell.fixed_slot >= 0:
			tile.equipped_key = "R"
		elif slot >= 0:
			tile.equipped_key = SHORT_KEYS[slot]
		tile.dropped.connect(_on_dropped)
		tile.hovered.connect(_on_tile_hovered)
		cell.add_child(tile)
		var name_label := Label.new()
		name_label.text = spell.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(76, 0)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIStyle.apply_label(name_label, 11, 3, spell.color.lightened(0.45))
		cell.add_child(name_label)
	for tile in _slot_tiles:
		tile.refresh(SpellSystem.get_equipped(tile.slot_index))
	_refresh_relics()
	_show_detail(null)


func _refresh_relics() -> void:
	for child in _relic_box.get_children():
		child.queue_free()
		_relic_box.remove_child(child)
	var owned := RelicSystem.get_owned()
	_relic_count.text = "%d / %d trang bị" % [owned.size(), RelicSystem.MAX_OWNED]
	if owned.is_empty():
		var none := Label.new()
		none.text = "Chưa có trang bị nào. Mua ở Relic Merchant trong sảnh chờ."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(420, 0)
		UIStyle.apply_label(none, 13, 3, Color(0.6, 0.6, 0.7))
		_relic_box.add_child(none)
	for relic in owned:
		var b := Button.new()
		b.icon = relic.icon
		b.add_theme_constant_override("icon_max_width", 56)
		b.custom_minimum_size = Vector2(72, 72)
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_entered.connect(func() -> void: _show_relic_detail(relic))
		b.pressed.connect(func() -> void: _show_relic_detail(relic))
		_relic_box.add_child(b)
	var player_node := get_tree().get_first_node_in_group("player")
	var hp_text := ""
	if player_node != null:
		hp_text = "Máu tối đa: %d\n" % int(float(player_node.get("max_health")))
	_stats_label.text = "%sSát thương: x%.2f\nHồi chiêu: -%d%%\nTốc độ chạy: x%.2f\nHồi máu khi hạ địch: +%d\nVàng rơi: x%.2f" % [
		hp_text, PlayerStats.damage_multiplier(), int(round((1.0 - PlayerStats.cooldown_multiplier()) * 100.0)),
		PlayerStats.move_speed_multiplier(), int(PlayerStats.kill_heal_amount()), PlayerStats.gold_multiplier()]


func _show_relic_detail(relic: RelicData) -> void:
	_detail_name.text = "%s  (giá gốc %d vàng)" % [relic.display_name, relic.price]
	_detail_text.text = relic.description


func _on_tile_hovered(tile: SpellTile) -> void:
	_show_detail(tile.spell)


func _show_detail(spell: SpellData) -> void:
	if spell == null:
		_detail_name.text = "Trỏ vào một spell để xem mô tả"
		_detail_text.text = ""
		return
	var cd := "" if spell.cooldown <= 0.0 else "  (hồi chiêu %s giây)" % str(snappedf(spell.cooldown, 0.01))
	_detail_name.text = spell.display_name + cd
	_detail_text.text = spell.description


# ---------------------------------------------------------------- Kéo thả
func _on_dropped(target: SpellTile, payload: Dictionary) -> void:
	var spell: SpellData = payload.get("spell")
	var from_slot: int = int(payload.get("from_slot", -1))
	if spell == null:
		return
	if target.role == SpellTile.Role.SLOT:
		if from_slot >= 0:
			SpellSystem.swap_slots(from_slot, target.slot_index)  # ô sang ô: đổi chỗ (ô đích trống thì chỉ chuyển)
		else:
			SpellSystem.assign_to_slot(target.slot_index, spell.id)
	elif from_slot >= 0:
		SpellSystem.unequip(from_slot)  # thả ô kỹ năng lên danh sách kho: tháo
	SpellSystem.inventory_changed.emit()
