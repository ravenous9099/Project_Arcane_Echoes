class_name HubPanel
extends CanvasLayer
## Hộp thoại ở sảnh chờ. Người Giữ Đèn: lời thoại + nút "Lưu tiến trình". Relic Merchant: cột HÀNG BÁN (mua) và cột TÚI RELIC (bán lại 50% giá).
## Mở bằng open_for(); tạm dừng game khi mở (PROCESS_MODE_ALWAYS để nút vẫn bấm được). Esc để đóng (xử lý trước PauseMenu bằng _input).

signal save_requested
signal closed

var is_open: bool = false

var _root: Control
var _title: Label
var _dialogue: Label
var _gold_label: Label
var _message: Label
var _body: VBoxContainer
var _kind: HubNpc.Kind = HubNpc.Kind.LAMP_KEEPER
var _selected: RelicData = null
var _selected_buying: bool = true
var _detail_box: VBoxContainer
var _detail_title: Label
var _detail_text: Label
var _action_btn: Button


func _ready() -> void:
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	Wallet.gold_changed.connect(func(_g: int, _d: int) -> void:
		_update_gold()
		if is_open and _kind == HubNpc.Kind.MERCHANT:
			_rebuild_shop())
	RelicSystem.relics_changed.connect(func() -> void:
		if is_open and _kind == HubNpc.Kind.MERCHANT:
			_rebuild_shop())


func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F):
		close()
		get_viewport().set_input_as_handled()


func open_for(kind: HubNpc.Kind, npc_name: String) -> void:
	if is_open:
		return
	_kind = kind
	_selected = null
	is_open = true
	_title.text = npc_name.to_upper()
	_message.text = ""
	_update_gold()
	if kind == HubNpc.Kind.LAMP_KEEPER:
		_build_lamp_keeper()
	else:
		_rebuild_shop()
	_root.visible = true
	get_tree().paused = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	closed.emit()


func show_message(text: String, color: Color = Color(0.7, 1.0, 0.7)) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


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
	panel.custom_minimum_size = Vector2(980.0, 0.0)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var head := HBoxContainer.new()
	outer.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.apply_label(_title, 24, 5, UIStyle.ACCENT)
	head.add_child(_title)
	_gold_label = Label.new()
	UIStyle.apply_label(_gold_label, 20, 4, Color(1.0, 0.88, 0.4))
	head.add_child(_gold_label)

	_dialogue = Label.new()
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.custom_minimum_size = Vector2(920.0, 0.0)
	UIStyle.apply_label(_dialogue, 15, 3, Color(0.92, 0.9, 0.85))
	outer.add_child(_dialogue)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	outer.add_child(_body)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_label(_message, 14, 3, Color(0.7, 1.0, 0.7))
	outer.add_child(_message)

	var close_btn := _make_button("Đóng  (Esc / F)", close)
	outer.add_child(close_btn)


func _make_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 40.0)
	UIStyle.apply_button(b, 12, 14)
	b.pressed.connect(on_pressed)
	return b


func _clear_body() -> void:
	for c in _body.get_children():
		c.queue_free()
		_body.remove_child(c)


func _update_gold() -> void:
	_gold_label.text = "%d vàng" % Wallet.gold


# ---------------------------------------------------------------- Người Giữ Đèn
func _build_lamp_keeper() -> void:
	_clear_body()
	var n := RelicSystem.bosses_defeated
	if n <= 0:
		_dialogue.text = "Chào, kẻ lữ hành. Ngọn đèn này giữ cho lối về không bao giờ tắt. Hãy tiến vào cổng phía bắc và hạ gục Boss của từng vùng đất; khi trở về ta sẽ ghi nhớ hành trình của ngươi."
	else:
		_dialogue.text = "Ngươi đã trở về, và còn nguyên vẹn. Ngọn đèn đã ghi lại %d Boss ngươi đã hạ. Muốn ta khắc tiến trình này lại để lần sau ngươi có thể tiếp tục không?" % n
	_body.add_child(_make_button("Lưu tiến trình", func() -> void:
		save_requested.emit()
		show_message("Đã lưu tiến trình. Menu chính sẽ có nút \"Tiếp tục\".")))


# ---------------------------------------------------------------- Relic Merchant
## Trang ngang: hàng "HÀNG BÁN" (biểu tượng + giá bên dưới), hàng "TRANG BỊ CỦA BẠN" (giá bán lại), và khung chi tiết hiệu ứng + nút Mua / Bán.
func _rebuild_shop() -> void:
	_clear_body()
	var stock := RelicSystem.get_stock()
	var owned := RelicSystem.get_owned()
	if RelicSystem.bosses_defeated <= 0:
		_dialogue.text = "Hừm... Hàng của ta chưa về. Hãy hạ một Boss rồi quay lại, ta sẽ có thứ đáng để ngươi trả vàng."
	elif stock.is_empty() and owned.is_empty():
		_dialogue.text = "Hôm nay ta hết hàng rồi. Hạ thêm Boss, ta sẽ nhập thêm relic."
	else:
		_dialogue.text = "Xem đi, xem đi. Bấm vào món nào để xem hiệu ứng. Ngươi cũng có thể bán lại relic cho ta với nửa giá."
	_body.add_child(_make_row("HÀNG BÁN", stock, true))
	_body.add_child(_make_row("TRANG BỊ CỦA BẠN  (%d/%d, bán lại 50%% giá)" % [owned.size(), RelicSystem.MAX_OWNED], owned, false))
	_build_detail_area()
	# Giữ lựa chọn cũ nếu món đó còn ở đúng hàng, ngược lại bỏ chọn.
	if _selected != null and not ((_selected_buying and stock.has(_selected)) or (not _selected_buying and owned.has(_selected))):
		_selected = null
	_update_detail()


func _make_row(title_text: String, relics: Array[RelicData], buying: bool) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	var t := Label.new()
	t.text = title_text
	UIStyle.apply_label(t, 14, 3, Color(0.95, 0.85, 0.55))
	section.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0.0, 118.0)
	section.add_child(row)
	if relics.is_empty():
		var empty := Label.new()
		empty.text = "(trống)"
		UIStyle.apply_label(empty, 13, 3, Color(0.6, 0.6, 0.7))
		row.add_child(empty)
		return section
	for relic in relics:
		row.add_child(_make_card(relic, buying))
	return section


## Một thẻ: biểu tượng relic (bấm để chọn) và giá nằm ngay bên dưới.
func _make_card(relic: RelicData, buying: bool) -> VBoxContainer:
	var price := relic.price if buying else RelicSystem.get_sell_price(relic)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	var b := Button.new()
	b.icon = relic.icon
	b.add_theme_constant_override("icon_max_width", 64)
	b.custom_minimum_size = Vector2(84.0, 84.0)
	b.focus_mode = Control.FOCUS_NONE
	UIStyle.apply_button(b, 10, 12)
	b.pressed.connect(func() -> void:
		_selected = relic
		_selected_buying = buying
		_update_detail())
	card.add_child(b)
	var name_label := Label.new()
	name_label.text = relic.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(84.0, 0.0)
	UIStyle.apply_label(name_label, 11, 3, Color(0.88, 0.88, 0.95))
	card.add_child(name_label)
	var price_label := Label.new()
	price_label.text = ("%d vàng" % price) if buying else ("+%d vàng" % price)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var affordable := (not buying) or Wallet.gold >= price
	UIStyle.apply_label(price_label, 14, 3, Color(1.0, 0.88, 0.4) if affordable else Color(1.0, 0.45, 0.4))
	card.add_child(price_label)
	return card


func _build_detail_area() -> void:
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_body.add_child(_detail_box)
	_detail_title = Label.new()
	UIStyle.apply_label(_detail_title, 17, 4, UIStyle.ACCENT)
	_detail_box.add_child(_detail_title)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(900.0, 52.0)
	UIStyle.apply_label(_detail_text, 14, 3, Color(0.9, 0.9, 0.85))
	_detail_box.add_child(_detail_text)
	_action_btn = _make_button("", _on_action_pressed)
	_detail_box.add_child(_action_btn)


func _update_detail() -> void:
	if _detail_title == null or not is_instance_valid(_detail_title):
		return
	if _selected == null:
		_detail_title.text = "Chọn một biểu tượng để xem hiệu ứng"
		_detail_text.text = ""
		_action_btn.visible = false
		return
	var relic := _selected
	_detail_title.text = relic.display_name
	var lines := relic.get_effect_lines()
	_detail_text.text = "%s\nHiệu ứng: %s" % [relic.description, "; ".join(lines)]
	_action_btn.visible = true
	if _selected_buying:
		_action_btn.text = "Mua  (%d vàng)" % relic.price
		_action_btn.disabled = Wallet.gold < relic.price
	else:
		_action_btn.text = "Bán  (nhận %d vàng)" % RelicSystem.get_sell_price(relic)
		_action_btn.disabled = false


func _on_action_pressed() -> void:
	var relic := _selected
	if relic == null:
		return
	if _selected_buying:
		var err := RelicSystem.try_buy(relic)
		if err != "":
			show_message(err, Color(1.0, 0.55, 0.5))
			SfxPlayer.play_sfx(&"ui_error")
			return
		show_message("Đã mua %s." % relic.display_name)
		SfxPlayer.play_sfx(&"buy")
	else:
		RelicSystem.sell(relic)
		show_message("Đã bán %s, nhận %d vàng." % [relic.display_name, RelicSystem.get_sell_price(relic)], Color(1.0, 0.9, 0.5))
		SfxPlayer.play_sfx(&"sell")
	_selected = null
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("refresh_stats"):
		player_node.call("refresh_stats")
