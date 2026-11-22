class_name EndingScreen
extends CanvasLayer
## Màn hình kết thúc game (sau khi hạ cả 3 Boss ở level 4): lời kết có tên người chơi, tổng kết lượt chơi, hạng trong Hall of Fame
## (kèm bảng top, hàng của bạn tô vàng) và nút về menu chính. Chạy cả khi game đang tạm dừng.

signal menu_requested
## Chơi lượt mới ngay với tên hiện tại (Main xử lý).
signal restart_requested

const MENU_SCENE := "res://Scenes/UI/MainMenu.tscn"


func show_ending(entry: Dictionary, result: Dictionary) -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(1152.0, 648.0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "CHIẾN THẮNG!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(title, 56, 8, UIStyle.ACCENT)
	box.add_child(title)
	var story := Label.new()
	story.text = "Ba Chúa tể đã ngã xuống, tiếng vọng cuối cùng tắt lặng trong hầm ngục.\n%s đã sống sót và trở về, ngọn đèn ở sảnh chờ sáng trở lại.\nTên của %s sẽ được khắc mãi trong Hall of Fame." % [String(entry.get("name", "")), String(entry.get("name", ""))]
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(story, 18, 4, Color(0.88, 0.9, 1.0))
	box.add_child(story)

	var rank := int(result.get("rank", 0))
	var rank_label := Label.new()
	rank_label.text = "Hạng trong Hall of Fame: #%d / %d     |     Điểm: %d     |     Sống sót: %s" % [rank, int(result.get("total", 0)), int(entry.get("score", 0)), HallOfFameView.format_time(int(entry.get("survival_sec", 0)))]
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(rank_label, 20, 4, Color(1.0, 0.9, 0.5))
	box.add_child(rank_label)
	var stats := Label.new()
	stats.text = "Spell đã dùng: %d   •   Tổng sát thương: %d   •   Hạ gục: %d   •   Relic đã mua: %d   •   Vàng kiếm được: %d   •   Combo cao nhất: %s" % [
		int(entry.get("spells_cast", 0)), int(entry.get("damage_dealt", 0)), int(entry.get("kills", 0)),
		int(entry.get("relics_bought", 0)), int(entry.get("gold_earned", 0)), String(entry.get("best_rank", "F"))]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(stats, 15, 3, Color(0.82, 0.86, 1.0))
	box.add_child(stats)

	var view := HallOfFameView.new()
	view.limit = 8
	view.highlight_id = int(result.get("id", -1))
	view.custom_minimum_size = Vector2(1000.0, 0.0)
	box.add_child(view)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	# Hai lựa chọn: chơi lượt mới với tên cũ, hoặc về menu chính (bấm "Chơi mới" để đặt tên mới).
	var again := Button.new()
	again.text = "CHƠI LẠI - GIỮ TÊN"
	again.custom_minimum_size = Vector2(260.0, 48.0)
	UIStyle.apply_button(again, 12, 18)
	again.pressed.connect(func() -> void: restart_requested.emit())
	buttons.add_child(again)
	var button := Button.new()
	button.text = "VỀ MENU CHÍNH"
	button.custom_minimum_size = Vector2(260.0, 48.0)
	UIStyle.apply_button(button, 12, 18)
	button.pressed.connect(_on_menu_pressed)
	buttons.add_child(button)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.8)


func _on_menu_pressed() -> void:
	menu_requested.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
