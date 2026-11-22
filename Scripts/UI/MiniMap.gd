class_name MiniMap
extends Control
## Mini map ở góc trên phải: hình thu nhỏ của map hiện tại, chấm ĐỎ cho từng Enemy đang sống (di chuyển theo thời gian thực),
## chấm xanh lá có vòng trắng cho Player, ô tím nhấp nháy cho cổng Boss, chấm vàng cho viên spell, chấm hồng cho viên máu.
## Boss hiện là chấm đỏ lớn có vòng. Dưới bản đồ ghi số Enemy còn trên level.
## Dữ liệu lấy từ MapGenerator (get_minimap_image) và các nhóm "enemies" / "spell_pickups" / "health_pickups"; không thêm bộ nhớ đáng kể.

@export var map_box: Vector2 = Vector2(190.0, 128.0)
## Số lần cập nhật chấm mỗi giây (vẽ lại nhẹ, không cần mỗi frame).
@export var refresh_rate: float = 12.0

var _world: MapGenerator = null
var _player: Node2D = null
var _texture: ImageTexture = null
var _cell_size: float = 32.0
var _map_rect: Rect2 = Rect2()  # vùng thực sự vẽ bản đồ (đã giữ tỉ lệ), toạ độ cục bộ của Control
var _scale: float = 1.0         # pixel mini map trên 1 pixel thế giới
var _time_left: float = 0.0
var _age: float = 0.0
var _enemy_count: int = 0


func _init() -> void:
	custom_minimum_size = map_box + Vector2(0.0, 22.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_age += delta
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 1.0 / maxf(refresh_rate, 1.0)
		_enemy_count = get_tree().get_node_count_in_group("enemies")
		queue_redraw()


## Main gọi sau mỗi lần sinh map (map khám phá hoặc phòng Boss) và khi có Player.
func set_source(world: MapGenerator, player: Node2D) -> void:
	_world = world
	_player = player
	_texture = null
	if world == null:
		queue_redraw()
		return
	var img := world.get_minimap_image()
	if img == null:
		queue_redraw()
		return
	_texture = ImageTexture.create_from_image(img)
	_cell_size = maxf(world.get_minimap_cell_size(), 1.0)
	var img_size := Vector2(img.get_width(), img.get_height())
	var fit := minf(map_box.x / img_size.x, map_box.y / img_size.y)
	var drawn := img_size * fit
	_map_rect = Rect2((map_box - drawn) * 0.5, drawn)
	_scale = fit / _cell_size
	queue_redraw()


func _world_to_mini(world_pos: Vector2) -> Vector2:
	var local := _world.to_local(world_pos)
	return _map_rect.position + local * _scale


func _draw() -> void:
	draw_style_box(UIStyle.box(12, Color(0.04, 0.04, 0.08, 0.82), Color(0.9, 0.82, 0.65, 0.55), 2), Rect2(Vector2(-4.0, -4.0), map_box + Vector2(8.0, 30.0)))
	if _texture == null or _world == null or not is_instance_valid(_world):
		draw_string(ThemeDB.fallback_font, Vector2(0.0, map_box.y * 0.5), "Chưa có bản đồ", HORIZONTAL_ALIGNMENT_CENTER, map_box.x, 12, Color(0.6, 0.6, 0.7))
		return
	draw_texture_rect(_texture, _map_rect, false)
	draw_rect(_map_rect, Color(0.8, 0.85, 1.0, 0.25), false, 1.0)

	# Cổng Boss.
	var portal := _world.get_portal()
	if portal != null and is_instance_valid(portal):
		var pp := _world_to_mini(portal.global_position)
		var blink := 0.55 + 0.45 * sin(_age * 5.0)
		draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -5), pp + Vector2(5, 0), pp + Vector2(0, 5), pp + Vector2(-5, 0)]), Color(0.8, 0.45, 1.0, blink))
		draw_polyline(PackedVector2Array([pp + Vector2(0, -6), pp + Vector2(6, 0), pp + Vector2(0, 6), pp + Vector2(-6, 0), pp + Vector2(0, -6)]), Color(1, 1, 1, 0.8), 1.0)

	# Viên spell và viên máu.
	for node in get_tree().get_nodes_in_group("spell_pickups"):
		var sp := _world_to_mini((node as Node2D).global_position)
		if _map_rect.grow(3.0).has_point(sp):
			var spell_col: Color = Color(1.0, 0.9, 0.3)
			var s: Variant = node.get("spell")
			if s != null:
				spell_col = (s as SpellData).color.lightened(0.3)
			draw_circle(sp, 3.0, Color(0, 0, 0, 0.6))
			draw_circle(sp, 2.2, spell_col)
	for node in get_tree().get_nodes_in_group("health_pickups"):
		var hp := _world_to_mini((node as Node2D).global_position)
		if _map_rect.grow(3.0).has_point(hp):
			draw_circle(hp, 2.2, Color(1.0, 0.4, 0.55))

	# Enemy: chấm đỏ; Boss: chấm lớn có vòng.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var ep := _world_to_mini(enemy.global_position)
		if not _map_rect.grow(2.0).has_point(ep):
			continue
		if enemy is Boss:
			draw_circle(ep, 5.5, Color(0.2, 0.0, 0.0, 0.9))
			draw_circle(ep, 4.2, Color(1.0, 0.2, 0.15))
			draw_arc(ep, 7.5 + sin(_age * 6.0), 0.0, TAU, 20, Color(1.0, 0.4, 0.3, 0.8), 1.5)
		else:
			draw_circle(ep, 2.6, Color(0.25, 0.0, 0.0, 0.85))
			draw_circle(ep, 1.9, Color(1.0, 0.18, 0.15))

	# Player.
	if _player != null and is_instance_valid(_player):
		var pl := _world_to_mini(_player.global_position)
		draw_circle(pl, 5.0, Color(1, 1, 1, 0.9))
		draw_circle(pl, 3.4, Color(0.3, 1.0, 0.45))

	# Số Enemy còn lại.
	draw_circle(Vector2(8.0, map_box.y + 11.0), 3.5, Color(1.0, 0.18, 0.15))
	draw_string(ThemeDB.fallback_font, Vector2(16.0, map_box.y + 16.0), "Enemy: %d" % _enemy_count, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.92, 0.9, 0.85))
	draw_circle(Vector2(map_box.x - 70.0, map_box.y + 11.0), 3.5, Color(0.3, 1.0, 0.45))
	draw_string(ThemeDB.fallback_font, Vector2(map_box.x - 62.0, map_box.y + 16.0), "Bạn", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.92, 0.9, 0.85))
