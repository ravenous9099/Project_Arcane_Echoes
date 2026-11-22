class_name Hub
extends Node2D
## Sảnh chờ kiểu hầm ngục đá (Wizard of Legend), dựng bằng code từ gói "Pixel Art Top Down - Basic v1.2.3" (đọc thẳng từ Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/):
## nền Stone Ground (ô đá 96 px, lối giữa có đinh), tường Tileset Wall (khối 64 px), cổng vòm Struct, tượng, cột, ghế đá,
## rương, thùng, bình, đá tảng, quan tài... (TX Props). Cổng dịch chuyển dùng bệ đá của cùng gói (BossPortal). Đặt ở HUB_ORIGIN, cách xa map chơi.
## Có: Người Giữ Đèn (lưu tiến trình), Relic Merchant (mua / bán relic) và cổng dịch chuyển sang level kế tiếp (đứng đủ lâu trong cổng để đi).
## Nhấn F gần NPC để nói chuyện. Main tạo Hub, gọi setup(), nghe signal leave_requested / save_requested.
## Mọi vùng cắt (Rect2 pixel gốc) là toạ độ đo từ ảnh gốc; ảnh vẽ ở tỉ lệ 1.0 (ô 32 px của gói khớp ô 32 px của game).

signal leave_requested
signal save_requested

const HUB_ORIGIN := Vector2(40000.0, 0.0)
const ROOM_SIZE := Vector2(1232.0, 752.0)
const WALL_TOP: float = 132.0
const SIDE_WALL: float = 40.0
const BOTTOM_WALL: float = 44.0
## Sàn: 12 cột x 6 hàng ô đá 96 px nằm giữa các bức tường.
const SLAB: float = 96.0
const FLOOR_COLS: int = 12
const FLOOR_ROWS: int = 6
const PORTAL_Y: float = 262.0

const TEX_PROPS: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Props.png")
const TEX_STRUCT: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Struct.png")
const TEX_WALL: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Tileset Wall.png")
const TEX_GROUND: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Tileset Stone Ground.png")

## tx_ground.png: hai ô đá 96x96 (trơn / có 4 đinh).
const R_SLAB_PLAIN := Rect2(0, 0, 96, 96)
const R_SLAB_STUD := Rect2(160, 0, 96, 96)
## tx_wall.png: hai khối tường 64x64 (đỉnh 16 px + thân + viền chân 4 px).
const R_BLOCK_A := Rect2(32, 288, 64, 64)
const R_BLOCK_B := Rect2(128, 288, 64, 64)
## Gói "Environment" (Tilesets/Dungeon_Tiles.png, ô 16 px, vẽ phóng 2x): cổng sắt, cờ, đèn tường màu. Tìm bằng MapTheme.find_root(); thiếu thì bỏ qua phần trang trí này.
const DUNGEON_TILES := "Tilesets/Dungeon_Tiles.png"
const R_GATE := Rect2(35, 114, 29, 46)
const R_BANNER := Rect2(87, 160, 18, 66)
const R_SCONCE_RED := Rect2(16, 286, 16, 16)
const R_SCONCE_BLUE := Rect2(64, 286, 16, 16)
const R_SCONCE_GREEN := Rect2(112, 286, 16, 16)
## tx_struct.png: cổng vòm đá (80x64); phần lõm của vòm nằm ở x 23..57, y 18..64 (toạ độ trong ảnh vòm).
const R_ARCH := Rect2(408, 27, 80, 64)
const ARCH_SCALE: float = 2.0
## tx_props.png (vùng cắt đã đo sát viền trong suốt):
const R_STATUE := Rect2(445, 20, 41, 73)
const R_PILLAR := Rect2(352, 174, 32, 77)
const R_BPILLAR := Rect2(416, 194, 32, 57)
const R_CHEST := Rect2(96, 30, 32, 31)
const R_CHEST_OPEN := Rect2(96, 76, 32, 49)
const R_CRATE := Rect2(160, 18, 32, 46)
const R_CRATE_S := Rect2(163, 86, 26, 39)
const R_BARREL := Rect2(162, 153, 28, 36)
const R_BENCH := Rect2(292, 19, 56, 41)
const R_SARC := Rect2(288, 87, 64, 36)
const R_ROCK_BIG := Rect2(3, 430, 57, 44)
const R_POT_A := Rect2(165, 217, 21, 34)
const R_POT_B := Rect2(164, 288, 25, 27)
const R_POT_C := Rect2(165, 348, 21, 32)
const R_SIGN_A := Rect2(99, 160, 27, 32)
const R_SIGN_B := Rect2(96, 224, 27, 32)
const R_RING := Rect2(420, 359, 55, 49)
const R_TOMB := Rect2(227, 9, 26, 52)

var panel: HubPanel
var _player: Node2D = null
var _npcs: Array[HubNpc] = []
var _portal: BossPortal = null
var _floor: Node2D = null
var _fx: Node2D = null
var _time: float = 0.0
var _next_level_name: String = ""
var _nearest: HubNpc = null
var _lamp_spots: Array[Vector2] = []
var _glow_spots: Array[Vector2] = []
var _shadows: Array[Rect2] = []
var _torch_spots: Array[Dictionary] = []  # {pos, color}
var _dungeon_tex: Texture2D = null


func setup(player: Node2D, next_level_name: String) -> void:
	_player = player
	_next_level_name = next_level_name
	position = HUB_ORIGIN


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var env_root := MapTheme.find_root()
	if not env_root.is_empty():
		_dungeon_tex = load(env_root + DUNGEON_TILES) as Texture2D
	var void_rect := Node2D.new()
	void_rect.z_index = -20
	void_rect.draw.connect(func() -> void: void_rect.draw_rect(Rect2(-3000.0, -3000.0, ROOM_SIZE.x + 6000.0, ROOM_SIZE.y + 6000.0), Color(0.02, 0.015, 0.02)))
	add_child(void_rect)
	_floor = Node2D.new()
	_floor.z_index = -10
	_floor.draw.connect(_draw_room)
	add_child(_floor)
	_build_colliders()
	_build_props()
	_fx = Node2D.new()
	_fx.z_index = -1
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_build_npcs()
	_portal = BossPortal.new()
	_portal.setup(56.0)
	_portal.position = Vector2(ROOM_SIZE.x * 0.5, PORTAL_Y)
	_portal.z_index = -8
	add_child(_portal)
	_portal.unlock()
	_portal.activated.connect(func() -> void: leave_requested.emit())
	panel = HubPanel.new()
	add_child(panel)
	panel.save_requested.connect(func() -> void: save_requested.emit())


func get_spawn_position() -> Vector2:
	return HUB_ORIGIN + Vector2(ROOM_SIZE.x * 0.5, ROOM_SIZE.y - 110.0)


func get_camera_rect() -> Rect2:
	return Rect2(HUB_ORIGIN, ROOM_SIZE)


func get_portal() -> BossPortal:
	return _portal


func get_portal_position() -> Vector2:
	return _portal.global_position if _portal != null else HUB_ORIGIN


# ---------------------------------------------------------------- Va chạm
func _build_colliders() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var t := 80.0
	var rects: Array[Rect2] = [
		Rect2(-t, -t, ROOM_SIZE.x + 2.0 * t, t + WALL_TOP + 6.0),
		Rect2(-t, ROOM_SIZE.y - BOTTOM_WALL, ROOM_SIZE.x + 2.0 * t, t + BOTTOM_WALL),
		Rect2(-t, 0.0, t + SIDE_WALL, ROOM_SIZE.y),
		Rect2(ROOM_SIZE.x - SIDE_WALL, 0.0, t + SIDE_WALL, ROOM_SIZE.y),
	]
	for r in rects:
		_add_box(body, r)


func _add_box(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.position + r.size * 0.5
	body.add_child(shape)


## Đặt một món đồ: pos là điểm giữa đáy của hình, scale_mul nhân thêm vào hệ số PX, collider là kích thước thân va chạm ở chân (ZERO = không chặn).


## Đặt một món đồ: pos là điểm giữa đáy của hình, scale_mul là tỉ lệ, collider là kích thước thân va chạm ở chân (ZERO = không chặn).
## shadow = true thì vẽ bóng elip mờ dưới chân (bóng nằm trong _draw_room).
func _add_prop(tex: Texture2D, region: Rect2, pos: Vector2, collider: Vector2 = Vector2.ZERO, scale_mul: float = 1.0, z: int = -3, shadow: bool = true) -> void:
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	sprite.texture = atlas
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * scale_mul
	sprite.position = pos - Vector2(region.size.x * scale_mul * 0.5, region.size.y * scale_mul)
	sprite.z_index = z
	add_child(sprite)
	if shadow:
		var sw := region.size.x * scale_mul * 0.84
		_shadows.append(Rect2(pos.x - sw * 0.5, pos.y - 4.0, sw, maxf(sw * 0.22, 8.0)))
	if collider != Vector2.ZERO:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		add_child(body)
		_add_box(body, Rect2(-collider.x * 0.5, -collider.y, collider.x, collider.y))


func _build_props() -> void:
	var w := ROOM_SIZE.x
	var h := ROOM_SIZE.y
	var cx := w * 0.5
	# Cổng vòm đá ở giữa tường sau (cổng dịch chuyển nằm ngay dưới); ruột vòm tối được vẽ trong _draw_room.
	_add_prop(TEX_STRUCT, R_ARCH, Vector2(cx, WALL_TOP + 8.0), Vector2.ZERO, ARCH_SCALE, -9, false)
	_build_wall_decor(cx)
	_add_prop(TEX_PROPS, R_STATUE, Vector2(cx - 150, 218), Vector2(26, 12))
	_add_prop(TEX_PROPS, R_STATUE, Vector2(cx + 150, 218), Vector2(26, 12))
	_add_prop(TEX_PROPS, R_PILLAR, Vector2(cx - 270, 222), Vector2(26, 12))
	_add_prop(TEX_PROPS, R_PILLAR, Vector2(cx + 270, 222), Vector2(26, 12))
	_add_prop(TEX_PROPS, R_BPILLAR, Vector2(146, 226), Vector2(26, 12))
	_add_prop(TEX_PROPS, R_BPILLAR, Vector2(w - 146, 226), Vector2(26, 12))
	_add_prop(TEX_PROPS, R_BENCH, Vector2(cx - 250, 420), Vector2(54, 14), 1, -2)
	_add_prop(TEX_PROPS, R_SIGN_A, Vector2(cx - 330, 432), Vector2(18, 10))
	_add_prop(TEX_PROPS, R_POT_A, Vector2(cx - 190, 424), Vector2(16, 10))
	_add_prop(TEX_PROPS, R_POT_C, Vector2(cx - 176, 440), Vector2(16, 10))
	_add_prop(TEX_PROPS, R_BENCH, Vector2(cx + 222, 420), Vector2(54, 14), 1, -2)
	_add_prop(TEX_PROPS, R_BENCH, Vector2(cx + 278, 420), Vector2(54, 14), 1, -2)
	_add_prop(TEX_PROPS, R_CRATE_S, Vector2(cx + 170, 426), Vector2(24, 12))
	_add_prop(TEX_PROPS, R_POT_B, Vector2(cx + 318, 424), Vector2(18, 10))
	_add_prop(TEX_PROPS, R_BARREL, Vector2(cx + 350, 430), Vector2(26, 14))
	_add_prop(TEX_PROPS, R_CRATE, Vector2(cx + 330, 380), Vector2(28, 14))
	_add_prop(TEX_PROPS, R_SARC, Vector2(118, 330), Vector2(60, 16))
	_add_prop(TEX_PROPS, R_SIGN_B, Vector2(182, 372), Vector2(18, 10))
	_add_prop(TEX_PROPS, R_ROCK_BIG, Vector2(100, 230), Vector2(44, 14))
	_add_prop(TEX_PROPS, R_CRATE, Vector2(w - 110, 230), Vector2(28, 14))
	_add_prop(TEX_PROPS, R_BARREL, Vector2(w - 150, 226), Vector2(26, 14))
	_add_prop(TEX_PROPS, R_CRATE_S, Vector2(w - 86, 276), Vector2(24, 12))
	_add_prop(TEX_PROPS, R_RING, Vector2(w - 130, 540), Vector2(44, 14))
	_add_prop(TEX_PROPS, R_CHEST, Vector2(150, h - 84), Vector2(28, 12))
	_add_prop(TEX_PROPS, R_CHEST_OPEN, Vector2(w - 170, h - 84), Vector2(28, 12))
	_add_prop(TEX_PROPS, R_POT_A, Vector2(cx - 210, h - 80), Vector2(14, 8))
	_add_prop(TEX_PROPS, R_POT_C, Vector2(cx + 220, h - 80), Vector2(14, 8))
	_add_prop(TEX_PROPS, R_ROCK_BIG, Vector2(w - 96, h - 66), Vector2(44, 14))
	_add_prop(TEX_PROPS, R_TOMB, Vector2(90, 560), Vector2(22, 10))
	_lamp_spots.append(Vector2(cx - 250.0, 376.0))
	_glow_spots.append(Vector2(cx - 150.0, 160.0))
	_glow_spots.append(Vector2(cx + 150.0, 160.0))


## Trang trí tường sau (gói Environment, thay cho 2 cửa gỗ cũ): cờ, cổng sắt và đèn tường màu, đặt xen kẽ, KHÔNG chồng lên nhau.
func _build_wall_decor(cx: float) -> void:
	if _dungeon_tex == null:
		return
	var wall_y := WALL_TOP + 2.0
	_add_prop(_dungeon_tex, R_BANNER, Vector2(cx - 130.0, wall_y), Vector2.ZERO, 1.8, -9, false)
	_add_prop(_dungeon_tex, R_BANNER, Vector2(cx + 130.0, wall_y), Vector2.ZERO, 1.8, -9, false)
	_add_prop(_dungeon_tex, R_GATE, Vector2(cx - 330.0, wall_y), Vector2.ZERO, 2.0, -9, false)
	_add_prop(_dungeon_tex, R_GATE, Vector2(cx + 330.0, wall_y), Vector2.ZERO, 2.0, -9, false)
	_add_prop(_dungeon_tex, R_BANNER, Vector2(cx - 500.0, wall_y), Vector2.ZERO, 1.8, -9, false)
	_add_prop(_dungeon_tex, R_BANNER, Vector2(cx + 500.0, wall_y), Vector2.ZERO, 1.8, -9, false)
	_add_torch(R_SCONCE_RED, Vector2(cx - 220.0, 92.0), Color(1.0, 0.35, 0.15))
	_add_torch(R_SCONCE_BLUE, Vector2(cx + 220.0, 92.0), Color(0.3, 0.55, 1.0))
	_add_torch(R_SCONCE_GREEN, Vector2(cx - 420.0, 92.0), Color(0.3, 1.0, 0.45))
	_add_torch(R_SCONCE_RED, Vector2(cx + 420.0, 92.0), Color(1.0, 0.35, 0.15))


func _add_torch(region: Rect2, pos: Vector2, glow_color: Color) -> void:
	_add_prop(_dungeon_tex, region, pos, Vector2.ZERO, 2.0, -8, false)
	_torch_spots.append({"pos": pos + Vector2(0.0, -16.0), "color": glow_color})


func _build_npcs() -> void:
	var w := ROOM_SIZE.x
	var keeper := HubNpc.new()
	keeper.setup(HubNpc.Kind.LAMP_KEEPER, "Người Giữ Đèn")
	keeper.position = Vector2(w * 0.5 - 250.0, 462.0)
	add_child(keeper)
	_npcs.append(keeper)
	var merchant := HubNpc.new()
	merchant.setup(HubNpc.Kind.MERCHANT, "Relic Merchant")
	merchant.position = Vector2(w * 0.5 + 250.0, 372.0)
	add_child(merchant)
	_npcs.append(merchant)


func _process(delta: float) -> void:
	_time += delta
	_fx.queue_redraw()
	if _player == null or not is_instance_valid(_player):
		return
	var nearest: HubNpc = null
	var best := INF
	for npc in _npcs:
		var d := npc.global_position.distance_to(_player.global_position)
		if d < npc.interact_radius and d < best:
			best = d
			nearest = npc
	for npc in _npcs:
		npc.set_near(npc == nearest and not panel.is_open)
	_nearest = nearest


func _unhandled_input(event: InputEvent) -> void:
	if panel == null or panel.is_open or _nearest == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		panel.open_for(_nearest.kind, _nearest.display_name)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Vẽ phòng
func _draw_room() -> void:
	var w := ROOM_SIZE.x
	var h := ROOM_SIZE.y
	var cx := w * 0.5
	# Sàn đá: lối giữa (2 cột) là ô có đinh dẫn tới cổng, còn lại ô trơn; mỗi ô lệch sáng tối nhẹ cho đỡ đơn điệu.
	for r in FLOOR_ROWS:
		for c in FLOOR_COLS:
			var studded := c == 5 or c == 6
			var v := 0.88 + 0.06 * float((r * 7 + c * 3) % 3)
			var src := R_SLAB_STUD if studded else R_SLAB_PLAIN
			_floor.draw_texture_rect_region(TEX_GROUND, Rect2(SIDE_WALL + c * SLAB, WALL_TOP + r * SLAB, SLAB, SLAB), src, Color(v, v, v * 1.08))
	# Tường sau: các khối 64 px xen kẽ A/B (trang trí tường nằm ở _build_wall_decor).
	var cols := int(ceil(w / 64.0))
	for i in cols:
		_wall_column(i * 64.0, 0.0, WALL_TOP, R_BLOCK_A if i % 2 == 0 else R_BLOCK_B, Color.WHITE)
	# Tường hai bên (tối hơn): lát dọc các lát thân khối.
	var side_tint := Color(0.68, 0.7, 0.84)
	var y := WALL_TOP
	while y < h - BOTTOM_WALL:
		var sh := minf(44.0, h - BOTTOM_WALL - y)
		var s := Rect2(R_BLOCK_A.position + Vector2(12.0, 16.0), Vector2(SIDE_WALL, sh))
		_floor.draw_texture_rect_region(TEX_WALL, Rect2(0.0, y, SIDE_WALL, sh), s, side_tint)
		_floor.draw_texture_rect_region(TEX_WALL, Rect2(w - SIDE_WALL, y, SIDE_WALL, sh), s, side_tint)
		y += 44.0
	# Tường dưới: đỉnh + thân + viền chân.
	for i in cols:
		var b := R_BLOCK_A if i % 2 == 0 else R_BLOCK_B
		_floor.draw_texture_rect_region(TEX_WALL, Rect2(i * 64.0, h - BOTTOM_WALL, 64.0, 40.0), Rect2(b.position, Vector2(64.0, 40.0)), side_tint)
		_floor.draw_texture_rect_region(TEX_WALL, Rect2(i * 64.0, h - 4.0, 64.0, 4.0), Rect2(b.position + Vector2(0.0, 60.0), Vector2(64.0, 4.0)), side_tint)
	# Bóng đổ ở chân tường.
	_floor.draw_rect(Rect2(SIDE_WALL, WALL_TOP, w - 2.0 * SIDE_WALL, 7.0), Color(0, 0, 0, 0.28))
	_floor.draw_rect(Rect2(SIDE_WALL, WALL_TOP + 7.0, w - 2.0 * SIDE_WALL, 7.0), Color(0, 0, 0, 0.12))
	_floor.draw_rect(Rect2(SIDE_WALL, WALL_TOP, 9.0, h - WALL_TOP - BOTTOM_WALL), Color(0, 0, 0, 0.22))
	_floor.draw_rect(Rect2(w - SIDE_WALL - 9.0, WALL_TOP, 9.0, h - WALL_TOP - BOTTOM_WALL), Color(0, 0, 0, 0.22))
	# Ruột tối của cổng vòm.
	var arch_o := Vector2(cx - R_ARCH.size.x * ARCH_SCALE * 0.5, WALL_TOP + 8.0 - R_ARCH.size.y * ARCH_SCALE)
	_floor.draw_rect(Rect2(arch_o + Vector2(46.0, 36.0), Vector2(68.0, 92.0)), Color(0.02, 0.015, 0.05, 0.94))
	# Bóng elip dưới chân các món đồ.
	for r in _shadows:
		_floor.draw_set_transform(r.get_center(), 0.0, Vector2(1.0, r.size.y / r.size.x))
		_floor.draw_circle(Vector2.ZERO, r.size.x * 0.5, Color(0, 0, 0, 0.3))
	_floor.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Một cột tường rộng 64 px từ y0 tới y1: đỉnh (60 px đầu của khối), các lát thân 44 px, rồi viền chân 4 px.
func _wall_column(x: float, y0: float, y1: float, block: Rect2, tint: Color) -> void:
	var y := y0
	_floor.draw_texture_rect_region(TEX_WALL, Rect2(x, y, 64.0, 60.0), Rect2(block.position, Vector2(64.0, 60.0)), tint)
	y += 60.0
	while y1 - y > 48.0:
		_floor.draw_texture_rect_region(TEX_WALL, Rect2(x, y, 64.0, 44.0), Rect2(block.position + Vector2(0.0, 16.0), Vector2(64.0, 44.0)), tint)
		y += 44.0
	var rem := y1 - y - 4.0
	if rem > 0.0:
		_floor.draw_texture_rect_region(TEX_WALL, Rect2(x, y, 64.0, rem), Rect2(block.position + Vector2(0.0, 16.0), Vector2(64.0, rem)), tint)
		y += rem
	_floor.draw_texture_rect_region(TEX_WALL, Rect2(x, y, 64.0, 4.0), Rect2(block.position + Vector2(0.0, 60.0), Vector2(64.0, 4.0)), tint)


## Hiệu ứng động: ánh sáng quanh cổng, tượng, đèn của Người Giữ Đèn, chữ "Tiếp theo".
func _draw_fx() -> void:
	var cx := ROOM_SIZE.x * 0.5
	var pg := 0.85 + 0.15 * sin(_time * 2.2)
	_fx.draw_set_transform(Vector2(cx, PORTAL_Y), 0.0, Vector2(1.0, 0.7))
	_fx.draw_circle(Vector2.ZERO, 150.0 * pg, Color(0.5, 0.35, 1.0, 0.07))
	_fx.draw_circle(Vector2.ZERO, 95.0 * pg, Color(0.6, 0.45, 1.0, 0.10))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for t in _torch_spots:
		var tf := 0.8 + 0.2 * sin(_time * 7.0 + float(t["pos"].x))
		var tc: Color = t["color"]
		_fx.draw_circle(t["pos"] + Vector2(0.0, 30.0), 80.0 * tf, Color(tc, 0.07))
		_fx.draw_circle(t["pos"] + Vector2(0.0, 30.0), 44.0 * tf, Color(tc, 0.10))
	for p in _glow_spots:
		var gp := 0.8 + 0.2 * sin(_time * 3.0 + p.x)
		_fx.draw_circle(p, 46.0 * gp, Color(0.6, 0.5, 1.0, 0.08))
	for p in _lamp_spots:
		var pulse := 0.85 + 0.15 * sin(_time * 3.0)
		_fx.draw_circle(p, 56.0 * pulse, Color(1.0, 0.85, 0.4, 0.10))
		_fx.draw_circle(p, 26.0 * pulse, Color(1.0, 0.85, 0.4, 0.18))
	var f2 := ThemeDB.fallback_font
	_fx.draw_string(f2, Vector2(cx - 120.0 + 1.0, WALL_TOP + 49.0), "Tiếp theo: %s" % _next_level_name, HORIZONTAL_ALIGNMENT_CENTER, 240.0, 15, Color(0, 0, 0, 0.8))
	_fx.draw_string(f2, Vector2(cx - 120.0, WALL_TOP + 48.0), "Tiếp theo: %s" % _next_level_name, HORIZONTAL_ALIGNMENT_CENTER, 240.0, 15, Color(1.0, 0.95, 0.75, 0.95))
