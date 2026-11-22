class_name SpellTile
extends Control
## Một ô trong bảng kho spell (InventoryPanel). Ba vai trò:
##   ITEM : một Spell trong kho (kéo đi được). Cũng nhận thả từ ô kỹ năng để THÁO spell về kho.
##   SLOT : một ô kỹ năng (chuột trái / Q / E / R). Nhận thả để trang bị. Kéo đi được (đổi chỗ hoặc tháo).
##   ZONE : nền của danh sách kho; thả spell từ ô kỹ năng lên đây để tháo.
## Kéo thả dùng cơ chế kéo-thả có sẵn của Godot (_get_drag_data / _can_drop_data / _drop_data), nên chạy cả khi game đang tạm dừng.
## Tile không tự đổi dữ liệu: nó chỉ phát signal dropped, InventoryPanel xử lý qua SpellSystem.

enum Role { ITEM, SLOT, ZONE }

## Bấm hoặc thả xong: target là tile nhận, payload = {"spell": SpellData, "from_slot": int (-1 nếu kéo từ kho)}.
signal dropped(target: SpellTile, payload: Dictionary)
signal hovered(tile: SpellTile)

var role: Role = Role.ITEM
var slot_index: int = -1
var spell: SpellData = null
var key_text: String = ""
## Ô bị khóa (ô R dành cho Ultimate): không nhận thả, không kéo được.
var locked: bool = false
## ITEM: Spell này đang ở ô kỹ năng nào (-1 = không ở ô nào), để hiện nhãn "Q".
var equipped_key: String = ""

var _hover: bool = false
var _drag_over: bool = false


func _init(p_role: Role = Role.ITEM, p_size: Vector2 = Vector2(64, 64)) -> void:
	role = p_role
	custom_minimum_size = p_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	if role == Role.ZONE:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hover = true
		hovered.emit(self)
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func refresh(p_spell: SpellData) -> void:
	spell = p_spell
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if VfxFrames.icon_is_pixel(spell) else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	tooltip_text = "" if spell == null else "%s\n%s" % [spell.display_name, spell.description]
	queue_redraw()


func _draw() -> void:
	if role == Role.ZONE:
		var zone_bg := UIStyle.box(12, Color(0.05, 0.045, 0.08, 0.85), Color(1.0, 0.82, 0.35, 0.9) if _drag_over else Color(0.5, 0.45, 0.6, 0.4), 2)
		draw_style_box(zone_bg, Rect2(Vector2.ZERO, size))
		return
	var col := spell.color if spell != null else Color(0.4, 0.4, 0.5)
	var border := CooldownSlot.HUD_RED if spell != null else Color(0.32, 0.32, 0.4)  # mọi kỹ năng dùng chung một màu đỏ
	if _drag_over:
		border = Color(1.0, 0.9, 0.4)
	elif _hover and not locked:
		border = border.lightened(0.35)
	var bg := UIStyle.box(10, Color(0.09, 0.08, 0.13, 0.95), border, 3 if (_hover or _drag_over) else 2)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	if spell != null:
		draw_circle(size * 0.5, size.x * 0.4, Color(col, 0.16))
		var tile_icon := VfxFrames.icon_for(spell)
		if tile_icon != null:
			var s := minf(size.x, size.y) - 14.0
			draw_texture_rect(tile_icon, Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)), false)
		else:
			draw_circle(size * 0.5, size.x * 0.25, col)
	elif role == Role.SLOT:
		var txt := "ULT" if locked else "+"
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0.0, size.y * 0.5 + 8.0), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22 if not locked else 16, Color(0.5, 0.5, 0.6, 0.7))
	if locked and spell == null:
		return
	if role == Role.ITEM and not equipped_key.is_empty():
		var badge := Rect2(size.x - 24.0, 3.0, 21.0, 17.0)
		draw_style_box(UIStyle.box(5, Color(0.1, 0.1, 0.16, 0.95), Color(1.0, 0.82, 0.35), 1), badge)
		draw_string(ThemeDB.fallback_font, Vector2(badge.position.x, badge.position.y + 13.0), equipped_key, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 12, Color(1.0, 0.9, 0.5))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if spell == null or locked or role == Role.ZONE:
		return null
	var preview := TextureRect.new()
	preview.texture = VfxFrames.icon_for(spell)
	if VfxFrames.icon_is_pixel(spell):
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = Vector2(56, 56)
	preview.size = Vector2(56, 56)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.position = Vector2(-28, -28)
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return {"spell": spell, "from_slot": slot_index if role == Role.SLOT else -1}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok := false
	if data is Dictionary and (data as Dictionary).has("spell"):
		var from_slot: int = int((data as Dictionary).get("from_slot", -1))
		match role:
			Role.SLOT:
				ok = not locked
			Role.ITEM, Role.ZONE:
				ok = from_slot >= 0  # chỉ để tháo từ ô kỹ năng
	_drag_over = ok
	queue_redraw()
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drag_over = false
	queue_redraw()
	dropped.emit(self, data as Dictionary)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if _drag_over:
			_drag_over = false
			queue_redraw()
