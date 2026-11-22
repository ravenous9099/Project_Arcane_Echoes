class_name SpellPickup
extends Area2D
## Viên Spell nằm trên map. Player chạm vào thì nhặt Spell (qua SpellSystem) và viên biến mất.
## Hình: BIỂU TƯỢNG của Spell (SpellData.icon) lơ lửng nhấp nhô trên một đế sáng, quầng sáng theo màu Spell, tia sáng và
## đom đóm xoay quanh, tên Spell hiện bên dưới. Phần thưởng của Boss (reward = true) lớn hơn và có cột sáng bắn lên trời.
## Được tạo bằng code (Main.gd, BossEncounter.gd), không cần scene riêng.

@export var spell: SpellData
@export var radius: float = 18.0
## Phần thưởng Boss: vẽ lớn hơn, có cột sáng.
@export var reward: bool = false

var _picked: bool = false
var _age: float = 0.0
var _icon: Texture2D = null


func _ready() -> void:
	add_to_group("spell_pickups")
	collision_layer = 0  # không bị ai khác "thấy"
	collision_mask = 1   # chỉ phát hiện vật thể ở layer 1 (Player)
	z_index = 5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_age = randf() * 6.0  # mỗi viên lệch pha nhau
	if spell != null:
		_icon = VfxFrames.icon_for(spell)  # icon -> khung signature (icon_folder/icon_frame) -> khung giữa của VFX
		if spell.icon == null and VfxFrames.icon_is_pixel(spell):
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var col := spell.color if spell != null else Color.WHITE
	var size_k := 1.45 if reward else 1.0
	var bob := sin(_age * 2.4) * 4.0 * size_k
	var pulse := 0.5 + 0.5 * sin(_age * 3.0)
	var base := Vector2(0.0, 6.0)
	var float_center := Vector2(0.0, -26.0 * size_k + bob)
	# Cột sáng của phần thưởng Boss.
	if reward:
		for i in 5:
			var w := 16.0 + 7.0 * (4 - i)
			draw_rect(Rect2(-w * 0.5, -230.0, w, 236.0), Color(col, 0.035 + 0.01 * i))
	# Đế: elip sáng + vòng chạy quanh.
	for g in 4:
		_draw_ellipse(base, Vector2(radius * (1.5 - 0.25 * g) * size_k, radius * (0.55 - 0.09 * g) * size_k), Color(col, 0.10 + 0.07 * g))
	var ring_r := radius * 1.25 * size_k
	for i in 8:
		var a := _age * 1.2 + TAU * float(i) / 8.0
		var p := base + Vector2(cos(a) * ring_r, sin(a) * ring_r * 0.38)
		draw_circle(p, 1.6 * size_k, Color(col.lightened(0.5), 0.8))
	# Quầng sáng sau biểu tượng.
	for g in 5:
		draw_circle(float_center, radius * size_k * (1.7 - 0.22 * g), Color(col, (0.05 + 0.03 * g) * (0.7 + 0.5 * pulse)))
	# Biểu tượng.
	var icon: Texture2D = _icon
	var icon_size := radius * 2.4 * size_k
	if icon != null:
		draw_texture_rect(icon, Rect2(float_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false)
	else:
		draw_circle(float_center, icon_size * 0.3, col)
		draw_arc(float_center, icon_size * 0.42, 0.0, TAU, 32, col.lightened(0.5), 2.0)
	# Tia lấp lánh bay quanh biểu tượng.
	for i in 4:
		var a2 := -_age * 1.7 + TAU * float(i) / 4.0
		var sp := float_center + Vector2(cos(a2), sin(a2) * 0.8) * icon_size * 0.62
		var tw := 0.5 + 0.5 * sin(_age * 6.0 + float(i) * 1.9)
		_draw_sparkle(sp, (2.0 + 2.5 * tw) * size_k, Color(1, 1, 1, 0.5 + 0.5 * tw))
	# Tên.
	if spell != null:
		var name_pos := Vector2(-70.0, 28.0 * size_k)
		draw_string(ThemeDB.fallback_font, name_pos + Vector2(1, 1), spell.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 12, Color(0, 0, 0, 0.8))
		draw_string(ThemeDB.fallback_font, name_pos, spell.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140.0, 12, col.lightened(0.5))


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _draw_sparkle(center: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.3, -r * 0.3), center + Vector2(r, 0), center + Vector2(r * 0.3, r * 0.3), center + Vector2(0, r), center + Vector2(-r * 0.3, r * 0.3), center + Vector2(-r, 0), center + Vector2(-r * 0.3, -r * 0.3)]), color)


func _on_body_entered(body: Node) -> void:
	if _picked or not body.is_in_group("player"):
		return
	_picked = true  # chặn xử lý trùng nếu signal bị gọi lần 2
	SpellSystem.collect_spell(spell)
	queue_free()
