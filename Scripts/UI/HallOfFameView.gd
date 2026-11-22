class_name HallOfFameView
extends PanelContainer
## Bảng Hall of Fame: các lượt chơi tốt nhất (đọc từ autoload HallOfFame). Dùng ở menu chính (nút "Hall of Fame") và ở màn hình kết thúc game.
## Mỗi hàng: hạng, tên, điểm, ngày giờ, thời gian sống sót, số lần dùng spell, tổng sát thương, số địch hạ gục, số relic đã mua, vàng đã kiếm,
## hạng combo cao nhất và kết cục (THẮNG / hạ mấy Boss). Hàng có id = highlight_id được tô vàng.

const COLUMNS: Array[Dictionary] = [
	{"title": "#", "min": 34.0},
	{"title": "Tên", "min": 130.0},
	{"title": "Điểm", "min": 70.0},
	{"title": "Ngày giờ", "min": 128.0},
	{"title": "Sống sót", "min": 70.0},
	{"title": "Spell", "min": 54.0},
	{"title": "Sát thương", "min": 86.0},
	{"title": "Hạ gục", "min": 60.0},
	{"title": "Relic", "min": 50.0},
	{"title": "Vàng", "min": 62.0},
	{"title": "Combo", "min": 56.0},
	{"title": "Kết cục", "min": 96.0},
]

var limit: int = 20
var highlight_id: int = -1


func _init() -> void:
	UIStyle.apply_panel(self, 16, 14.0)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	refresh()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "HALL OF FAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(title, 30, 6, UIStyle.ACCENT)
	box.add_child(title)
	var rows := HallOfFame.get_top(limit)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Chưa có lượt chơi nào được ghi lại. Hãy chơi và để lại tên của bạn!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.apply_label(empty, 16, 3, Color(0.8, 0.8, 0.9))
		box.add_child(empty)
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 300.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for col in COLUMNS:
		grid.add_child(_cell(String(col["title"]), float(col["min"]), Color(0.75, 0.82, 1.0), 14))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var mine := int(r.get("id", -1)) == highlight_id
		var color := Color(1.0, 0.9, 0.45) if mine else (Color(0.95, 0.95, 1.0) if i % 2 == 0 else Color(0.82, 0.84, 0.95))
		var values: Array[String] = [
			str(i + 1), String(r.get("name", "?")), str(int(r.get("score", 0))), String(r.get("finished_at", "")),
			format_time(int(r.get("survival_sec", 0))), str(int(r.get("spells_cast", 0))), str(int(r.get("damage_dealt", 0))),
			str(int(r.get("kills", 0))), str(int(r.get("relics_bought", 0))), str(int(r.get("gold_earned", 0))),
			String(r.get("best_rank", "F")), result_text(r),
		]
		for c in COLUMNS.size():
			grid.add_child(_cell(values[c], float(COLUMNS[c]["min"]), color, 14))


func _cell(text: String, min_width: float, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(min_width, 0.0)
	label.clip_text = true
	UIStyle.apply_label(label, font_size, 3, color)
	return label


static func format_time(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [seconds / 60, seconds % 60]


static func result_text(row: Dictionary) -> String:
	if bool(row.get("completed", false)):
		return "THẮNG GAME"
	var level_name := HallOfFame.catalog_name("levels", String(row.get("level_reached", "")))
	return "%s · %d Boss" % [level_name, int(row.get("bosses_defeated", 0))]
