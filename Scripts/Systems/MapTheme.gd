class_name MapTheme
extends RefCounted
## Bộ "giao diện" của một map: ảnh nền, ảnh đường, danh sách vật cản (cây, bụi, đá, tàn tích, cỏ trang trí) và màu đấu trường Boss.
## MapGenerator nhận một MapTheme qua set_theme(); không có theme (null) thì dùng bộ mặc định (Pixel Art Top Down - Basic).
## Hiện có theme "autumn" và "winter" dựng từ gói asset "Environment" (ô 16 px, được phóng 2x lên ô 32 px của map),
## và theme "dungeon" (level 4) trộn cả hai gói: sàn / đá của "Environment" + tường, cột, tượng, hòm của "Pixel Art Top Down - Basic".
## Nếu thiếu file ảnh, create() trả về null và in cảnh báo (game tự dùng theme mặc định, không bị sập).

## Các thư mục có thể chứa gói "Environment" (kiểm tra theo thứ tự). Đặt gói ở MỘT trong các chỗ này, hoặc sửa extra_roots.
const CANDIDATE_ROOTS: Array[String] = [
	"res://Assets/Environment/",
	"res://Assets/Enviroments/Environment/",
	"res://Assets/Environments/Environment/",
	"res://Assets/Enviroments/Environment Pack/Environment/",
]
## Gói "Pixel Art Top Down - Basic" (ảnh 32 px, dùng ở tỉ lệ 1.0).
const PIXEL_ART_ROOT := "res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/"
## Thêm đường dẫn riêng (kết thúc bằng "/") nếu bạn đặt gói ở nơi khác.
static var extra_roots: Array[String] = []

var id: StringName = &"default"
## Kích thước ô trong ảnh nền/đường (pixel). Map phóng ô này lên tile_size của MapGenerator.
var tile_px: int = 16
var ground_texture: Texture2D = null
var path_texture: Texture2D = null
var ground_tiles: Array[Vector2i] = []
var path_tiles: Array[Vector2i] = []
## Mỗi phần tử là một Dictionary tạo bởi make_def().
var trees: Array = []
var bushes: Array = []
var rocks: Array = []
## Đúng 8 phần tử (MapGenerator tham chiếu theo chỉ số): 0,1 bia/gốc nhỏ, 2 tượng, 3 cột, 4 cột gãy, 5 ghế dài (2 ô), 6 thùng, 7 thùng tròn.
var ruins: Array = []
var decor: Array = []
## Màu/tile của đấu trường Boss.
var arena_bg: Color = Color(0.05, 0.03, 0.02)
var arena_rim: Color = Color(0.95, 0.55, 0.25, 0.95)
var arena_ring: Color = Color(0.55, 0.36, 0.2, 0.7)
var arena_rune: Color = Color(1.0, 0.7, 0.3, 0.9)
var arena_tint: Color = Color(1.0, 1.0, 1.0)
var arena_tiles: Array[Vector2i] = []
## Bố cục vật cản trong đấu trường Boss. Mỗi phần tử Vector3(góc độ, tỉ lệ bán kính 0..1, bán kính ô). Để trống = 4 cột mặc định.
## Mỗi vật cản là một khối chặn cả người, đạn lẫn đường đi nên dùng làm chỗ NÚP.
var arena_pillars: Array[Vector3] = []
## Màu vẽ cột (viền tối, thân, mảng sáng) khi không có hình riêng.
var pillar_dark: Color = Color(0.08, 0.05, 0.03)
var pillar_mid: Color = Color(0.42, 0.3, 0.2)
var pillar_light: Color = Color(0.58, 0.42, 0.28)
## Đấu trường HÌNH CHỮ NHẬT (thay cho hình tròn): arena_grid = kích thước lưới (ô 16 px), arena_half_cells = nửa chiều rộng / cao vùng chơi (ô).
## arena_rect_pillars: mỗi phần tử Vector3(x, y, bán kính ô) với x, y trong -1..1 theo nửa kích thước vùng chơi (khác arena_pillars dùng góc + tỉ lệ bán kính).
var arena_rect: bool = false
var arena_grid: Vector2i = Vector2i(120, 84)
var arena_half_cells: Vector2 = Vector2(52.0, 34.0)
var arena_rect_pillars: Array[Vector3] = []
## Ảnh khối tường (TX Tileset Wall) để vẽ viền đấu trường chữ nhật; rỗng = chỉ vẽ viền màu.
var wall_texture: Texture2D = null
## Hình vẽ đè lên cột (tuỳ chọn): các def từ make_def(), luân phiên theo thứ tự. Trống = chỉ vẽ hình tròn.
var pillar_sprites: Array = []


## Tạo theme theo mã. Trả về null cho "default" hoặc khi thiếu asset.
static func create(theme_id: StringName) -> MapTheme:
	match theme_id:
		&"autumn":
			return _create_autumn()
		&"winter":
			return _create_winter()
		&"dungeon":
			return _create_dungeon()
	return null


static var _root_cache: String = ""


static func find_root() -> String:
	if not _root_cache.is_empty():
		return _root_cache
	var roots: Array[String] = []
	roots.append_array(extra_roots)
	roots.append_array(CANDIDATE_ROOTS)
	for root in roots:
		if _has_pack(root):
			_root_cache = root
			return root
	# Không nằm ở chỗ định sẵn: quét thư mục Assets (sâu tối đa 5 cấp) tìm thư mục chứa Tilesets/Floors_Tiles.png.
	var found := _scan_for_pack("res://Assets/", 0)
	if found.is_empty():
		found = _scan_for_pack("res://", 0)
	_root_cache = found
	if not found.is_empty():
		print("[MapTheme] Tìm thấy gói Environment tại ", found)
	return found


static func _has_pack(root: String) -> bool:
	return ResourceLoader.exists(root + "Tilesets/Floors_Tiles.png") or FileAccess.file_exists(root + "Tilesets/Floors_Tiles.png")


static func _scan_for_pack(dir_path: String, depth: int) -> String:
	if depth > 5:
		return ""
	if _has_pack(dir_path):
		return dir_path
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var subs: Array[String] = []
	for sub in dir.get_directories():
		if not sub.begins_with(".") and sub != "addons":
			subs.append(sub)
	for sub in subs:
		var r := _scan_for_pack(dir_path.path_join(sub) + "/", depth + 1)
		if not r.is_empty():
			return r
	return ""


## Một vật cản: ảnh cắt từ sheet (region, pixel gốc), vùng va chạm ở CHÂN vật (collision, pixel thế giới SAU khi phóng),
## số ô chiếm (footprint) và hệ số phóng của ảnh (scale).
static func make_def(tex: Texture2D, region: Rect2, collision: Vector2, footprint: Vector2i = Vector2i(1, 1), sprite_scale: float = 1.0) -> Dictionary:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	var shape: RectangleShape2D = null
	if collision.x > 0.0 and collision.y > 0.0:
		shape = RectangleShape2D.new()
		shape.size = collision
	return {"atlas": atlas, "region": region, "shape": shape, "collision": collision, "footprint": footprint, "scale": Vector2.ONE * sprite_scale}


static func _create_autumn() -> MapTheme:
	var root := find_root()
	if root.is_empty():
		push_warning("MapTheme: không tìm thấy gói asset 'Environment' (đã tìm: %s). Level 2 sẽ dùng giao diện mặc định." % ", ".join(CANDIDATE_ROOTS))
		return null
	var floors := load(root + "Tilesets/Floors_Tiles.png") as Texture2D
	var tree_a := load(root + "Props/Static/Trees/Model_01/Size_03.png") as Texture2D
	var tree_b := load(root + "Props/Static/Trees/Model_03/Size_03.png") as Texture2D
	var veg := load(root + "Props/Static/Vegetation.png") as Texture2D
	var rocks_tex := load(root + "Props/Static/Rocks.png") as Texture2D
	var res_tex := load(root + "Props/Static/Resources.png") as Texture2D
	if floors == null or tree_a == null or tree_b == null or veg == null or rocks_tex == null or res_tex == null:
		push_warning("MapTheme: thiếu một số file ảnh trong '%s'. Level 2 sẽ dùng giao diện mặc định." % root)
		return null

	var t := MapTheme.new()
	t.id = &"autumn"
	t.tile_px = 16
	# Nền: đất nâu (các ô đặc, không viền). Đường: gạch xám (tương phản rõ với nền).
	t.ground_texture = floors
	t.ground_tiles = [Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10), Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11)]
	t.path_texture = floors
	t.path_tiles = [Vector2i(16, 0), Vector2i(17, 1), Vector2i(16, 2), Vector2i(17, 3), Vector2i(18, 0), Vector2i(15, 2)]
	# Đấu trường Level 2 ("sân cát tàn tích"): nền cát cam (không còn gạch xám), viền vàng đồng, 8 cột đá nhỏ xếp vòng ngoài.
	t.arena_tiles = [Vector2i(5, 22), Vector2i(6, 22), Vector2i(7, 22), Vector2i(8, 23), Vector2i(9, 23), Vector2i(5, 24), Vector2i(7, 25)]
	t.arena_bg = Color(0.08, 0.04, 0.02)
	t.arena_rim = Color(1.0, 0.75, 0.25, 0.95)
	t.arena_ring = Color(0.65, 0.35, 0.15, 0.55)
	t.arena_rune = Color(1.0, 0.45, 0.2, 0.95)
	for k in 8:
		t.arena_pillars.append(Vector3(22.5 + 45.0 * k, 0.8, 1.4))

	# Cây: 3 cây lá rụng (cam, vàng cam, trụi) + 2 cây thông (nâu, đỏ). Collision chỉ ở gốc.
	t.trees = [
		make_def(tree_a, Rect2(0, 96, 48, 96), Vector2(18, 12), Vector2i(1, 1), 1.5),
		make_def(tree_a, Rect2(48, 96, 48, 96), Vector2(18, 12), Vector2i(1, 1), 1.5),
		make_def(tree_a, Rect2(96, 96, 48, 96), Vector2(18, 12), Vector2i(1, 1), 1.5),
		make_def(tree_b, Rect2(0, 144, 64, 144), Vector2(14, 10), Vector2i(1, 1), 1.1),
		make_def(tree_b, Rect2(64, 144, 64, 144), Vector2(14, 10), Vector2i(1, 1), 1.1),
	]
	# Bụi: tán lá vàng cam và đỏ gạch, ba cỡ (nhỏ / vừa / lớn).
	t.bushes = [
		make_def(veg, Rect2(96, 4, 32, 29), Vector2(24, 12), Vector2i(1, 1), 1.3),
		make_def(veg, Rect2(100, 33, 38, 33), Vector2(28, 14), Vector2i(1, 1), 1.3),
		make_def(veg, Rect2(98, 65, 44, 32), Vector2(32, 14), Vector2i(1, 1), 1.3),
		make_def(veg, Rect2(146, 4, 31, 29), Vector2(24, 12), Vector2i(1, 1), 1.3),
		make_def(veg, Rect2(149, 33, 38, 33), Vector2(28, 14), Vector2i(1, 1), 1.3),
		make_def(veg, Rect2(146, 65, 44, 32), Vector2(32, 14), Vector2i(1, 1), 1.3),
	]
	# Đá: nâu và xám, cao / vừa / dẹt / nhỏ.
	t.rocks = [
		make_def(rocks_tex, Rect2(98, 19, 28, 43), Vector2(30, 16), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(35, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(65, 17, 31, 14), Vector2(38, 12), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(161, 17, 31, 14), Vector2(38, 12), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(48, 51, 15, 10), Vector2(20, 10), Vector2i(1, 1), 1.6),
	]
	# Tàn tích (đúng thứ tự chỉ số mà MapGenerator dùng).
	t.ruins = [
		make_def(tree_a, Rect2(193, 10, 14, 22), Vector2(22, 12), Vector2i(1, 1), 1.6),   # 0 gốc cây
		make_def(tree_a, Rect2(193, 42, 14, 22), Vector2(22, 12), Vector2i(1, 1), 1.6),   # 1 gốc cây
		make_def(rocks_tex, Rect2(98, 19, 28, 43), Vector2(36, 18), Vector2i(1, 1), 2.0), # 2 tảng đá cao xám (thay tượng)
		make_def(rocks_tex, Rect2(2, 19, 28, 43), Vector2(36, 18), Vector2i(1, 1), 2.0),  # 3 tảng đá cao nâu (thay cột)
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(34, 16), Vector2i(1, 1), 1.8),# 4 đá vỡ
		make_def(res_tex, Rect2(0, 156, 31, 20), Vector2(56, 16), Vector2i(2, 1), 2.0),   # 5 khúc gỗ nằm (2 ô)
		make_def(rocks_tex, Rect2(35, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.6), # 6 đá nâu
		make_def(rocks_tex, Rect2(65, 17, 31, 14), Vector2(38, 12), Vector2i(1, 1), 1.6), # 7 đá dẹt
	]
	# Trang trí không va chạm: cành khô, nấm, hoa cam.
	t.decor = [
		make_def(veg, Rect2(243, 2, 9, 11), Vector2.ZERO, Vector2i(1, 1), 2.0),
		make_def(veg, Rect2(260, 0, 9, 16), Vector2.ZERO, Vector2i(1, 1), 2.0),
		make_def(veg, Rect2(276, 0, 11, 14), Vector2.ZERO, Vector2i(1, 1), 2.0),
		make_def(veg, Rect2(36, 340, 8, 9), Vector2.ZERO, Vector2i(1, 1), 2.0),
		make_def(veg, Rect2(49, 338, 14, 14), Vector2.ZERO, Vector2i(1, 1), 2.0),
		make_def(veg, Rect2(113, 338, 13, 9), Vector2.ZERO, Vector2i(1, 1), 2.0),
		make_def(veg, Rect2(53, 373, 7, 6), Vector2.ZERO, Vector2i(1, 1), 2.0),
		make_def(veg, Rect2(100, 373, 8, 7), Vector2.ZERO, Vector2i(1, 1), 2.0),
	]
	return t


static func _create_winter() -> MapTheme:
	var root := find_root()
	if root.is_empty():
		push_warning("MapTheme: không tìm thấy gói asset 'Environment' (đã tìm: %s). Level 3 sẽ dùng giao diện mặc định." % ", ".join(CANDIDATE_ROOTS))
		return null
	var floors := load(root + "Tilesets/Floors_Tiles.png") as Texture2D
	var tree_a := load(root + "Props/Static/Trees/Model_01/Size_03.png") as Texture2D
	var tree_b := load(root + "Props/Static/Trees/Model_02/Size_03.png") as Texture2D
	var rocks_tex := load(root + "Props/Static/Rocks.png") as Texture2D
	var res_tex := load(root + "Props/Static/Resources.png") as Texture2D
	if floors == null or tree_a == null or tree_b == null or rocks_tex == null or res_tex == null:
		push_warning("MapTheme: thiếu một số file ảnh trong '%s'. Level 3 sẽ dùng giao diện mặc định." % root)
		return null

	var t := MapTheme.new()
	t.id = &"winter"
	t.tile_px = 16
	# Nền: tuyết trắng (ô đặc, không viền). Đường: gạch xám phủ sương. Đấu trường: băng xanh.
	t.ground_texture = floors
	t.ground_tiles = [Vector2i(0, 22), Vector2i(1, 22), Vector2i(2, 22), Vector2i(3, 22), Vector2i(1, 23), Vector2i(2, 23), Vector2i(3, 23), Vector2i(4, 23)]
	t.path_texture = floors
	t.path_tiles = [Vector2i(16, 0), Vector2i(17, 1), Vector2i(16, 2), Vector2i(17, 3), Vector2i(18, 0), Vector2i(15, 2)]
	t.arena_tiles = [Vector2i(0, 24), Vector2i(1, 24), Vector2i(2, 24), Vector2i(3, 25), Vector2i(4, 25), Vector2i(1, 25)]
	t.arena_bg = Color(0.03, 0.05, 0.1)
	t.arena_rim = Color(0.6, 0.9, 1.0, 0.95)
	t.arena_ring = Color(0.5, 0.7, 0.95, 0.5)
	t.arena_rune = Color(0.7, 0.95, 1.0, 0.95)
	t.arena_tint = Color(0.95, 0.98, 1.0)
	# Chỗ nấp = cây thông phủ tuyết đứng trên đụn tuyết (không còn cột đá/băng).
	t.pillar_dark = Color(0.45, 0.55, 0.68)
	t.pillar_mid = Color(0.86, 0.92, 0.98)
	t.pillar_light = Color(1.0, 1.0, 1.0)
	# Phòng Boss 3: nhiều khối đá/băng để NÚP đạn. Vòng trong 4 khối, vòng ngoài 6 khối chừa lối xuất phát ở phía dưới.
	for k in 4:
		t.arena_pillars.append(Vector3(45.0 + 90.0 * k, 0.36, 2.0))
	for k in 6:
		t.arena_pillars.append(Vector3(60.0 * k, 0.7, 2.4))
	t.pillar_sprites = [
		make_def(tree_b, Rect2(0, 0, 48, 80), Vector2.ZERO),
		make_def(tree_b, Rect2(48, 0, 48, 80), Vector2.ZERO),
		make_def(tree_b, Rect2(0, 80, 48, 80), Vector2.ZERO),
		make_def(tree_b, Rect2(48, 80, 48, 80), Vector2.ZERO),
	]

	# Cây: 2 cây phủ băng, 2 cây thông xanh lạnh, 1 cây trụi. Collision chỉ ở gốc.
	t.trees = [
		make_def(tree_a, Rect2(141, 0, 51, 96), Vector2(18, 12), Vector2i(1, 1), 1.5),
		make_def(tree_a, Rect2(141, 96, 51, 96), Vector2(18, 12), Vector2i(1, 1), 1.5),
		make_def(tree_b, Rect2(0, 0, 48, 80), Vector2(14, 10), Vector2i(1, 1), 1.4),
		make_def(tree_b, Rect2(48, 0, 48, 80), Vector2(14, 10), Vector2i(1, 1), 1.4),
		make_def(tree_b, Rect2(96, 0, 48, 80), Vector2(12, 10), Vector2i(1, 1), 1.4),
	]
	# "Bụi": đá xám thấp (không dùng tinh thể băng).
	t.bushes = [
		make_def(rocks_tex, Rect2(160, 63, 16, 14), Vector2(24, 12), Vector2i(1, 1), 2.0),
		make_def(rocks_tex, Rect2(176, 63, 16, 14), Vector2(24, 12), Vector2i(1, 1), 2.0),
		make_def(rocks_tex, Rect2(144, 62, 16, 14), Vector2(24, 12), Vector2i(1, 1), 2.0),
		make_def(rocks_tex, Rect2(161, 17, 31, 14), Vector2(34, 12), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.4),
		make_def(rocks_tex, Rect2(128, 62, 16, 14), Vector2(22, 10), Vector2i(1, 1), 2.0),
	]
	t.rocks = [
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.6),
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(161, 17, 31, 14), Vector2(38, 12), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.7),
	]
	# Tàn tích (đúng thứ tự chỉ số mà MapGenerator dùng).
	t.ruins = [
		make_def(tree_a, Rect2(193, 8, 14, 22), Vector2(22, 12), Vector2i(1, 1), 1.6),    # 0 gốc cây (không băng)
		make_def(tree_a, Rect2(193, 40, 14, 22), Vector2(22, 12), Vector2i(1, 1), 1.6),   # 1 gốc cây (không băng)
		make_def(tree_b, Rect2(0, 80, 48, 80), Vector2(14, 10), Vector2i(1, 1), 1.3),     # 2 cây thông nhỏ (thay tượng)
		make_def(tree_b, Rect2(48, 80, 48, 80), Vector2(14, 10), Vector2i(1, 1), 1.4),    # 3 cây thông (thay cột)
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(34, 16), Vector2i(1, 1), 1.8),# 4 đá vỡ
		make_def(res_tex, Rect2(0, 156, 31, 20), Vector2(56, 16), Vector2i(2, 1), 2.0),   # 5 khúc gỗ nằm (2 ô)
		make_def(rocks_tex, Rect2(161, 17, 31, 14), Vector2(38, 12), Vector2i(1, 1), 1.6),# 6 đá dẹt
		make_def(rocks_tex, Rect2(160, 63, 16, 14), Vector2(24, 10), Vector2i(1, 1), 2.0),# 7 đá nhỏ
	]
	# Trang trí không va chạm: đá nhỏ và mảnh băng.
	t.decor = [
		make_def(rocks_tex, Rect2(161, 17, 31, 14), Vector2.ZERO, Vector2i(1, 1), 0.8),
		make_def(rocks_tex, Rect2(144, 62, 16, 14), Vector2.ZERO, Vector2i(1, 1), 1.0),
		make_def(rocks_tex, Rect2(160, 63, 16, 14), Vector2.ZERO, Vector2i(1, 1), 1.4),
		make_def(rocks_tex, Rect2(176, 63, 16, 14), Vector2.ZERO, Vector2i(1, 1), 1.4),
		make_def(rocks_tex, Rect2(128, 62, 16, 14), Vector2.ZERO, Vector2i(1, 1), 1.4),
		make_def(rocks_tex, Rect2(144, 62, 16, 14), Vector2.ZERO, Vector2i(1, 1), 1.4),
	]
	return t


## Level 4: hầm ngục đá. Sàn tối (Environment/Dungeon_Tiles), đường gạch xám (Environment/Floors_Tiles), vật cản là cột, tượng, bia mộ, khối tường,
## thùng, bình, đá (Pixel Art Top Down). Đấu trường chữ nhật rộng, viền tường đá, 6 cột để nấp.
static func _create_dungeon() -> MapTheme:
	var root := find_root()
	if root.is_empty():
		push_warning("MapTheme: không tìm thấy gói asset 'Environment'. Level 4 sẽ dùng giao diện mặc định.")
		return null
	var floors := load(root + "Tilesets/Floors_Tiles.png") as Texture2D
	var dungeon := load(root + "Tilesets/Dungeon_Tiles.png") as Texture2D
	var rocks_tex := load(root + "Props/Static/Rocks.png") as Texture2D
	var props := _load_pixel_art("TX Props.png")
	var wall := _load_pixel_art("TX Tileset Wall.png")
	if floors == null or dungeon == null or rocks_tex == null or props == null or wall == null:
		push_warning("MapTheme: thiếu ảnh cho theme dungeon (Environment: Floors_Tiles, Dungeon_Tiles, Rocks; Pixel Art Top Down: TX Props, TX Tileset Wall). Level 4 dùng giao diện mặc định.")
		return null

	var t := MapTheme.new()
	t.id = &"dungeon"
	t.tile_px = 16
	# Nền (chỗ không đi được): sàn xanh đen có kẻ ô. Đường / phòng: gạch xám.
	t.ground_texture = dungeon
	t.ground_tiles = [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2), Vector2i(6, 2)]
	t.path_texture = floors
	t.path_tiles = [Vector2i(16, 0), Vector2i(17, 1), Vector2i(16, 2), Vector2i(17, 3), Vector2i(18, 0), Vector2i(15, 2)]
	# Đấu trường chữ nhật rộng (viền tường đá).
	t.arena_tiles = [Vector2i(16, 0), Vector2i(17, 1), Vector2i(16, 2), Vector2i(17, 3), Vector2i(18, 0), Vector2i(15, 2)]
	t.arena_tint = Color(0.72, 0.72, 0.88)
	t.arena_bg = Color(0.02, 0.02, 0.04)
	t.arena_rim = Color(0.75, 0.8, 1.0, 0.9)
	t.arena_ring = Color(0.5, 0.55, 0.8, 0.45)
	t.arena_rune = Color(0.7, 0.55, 1.0, 0.9)
	t.arena_rect = true
	t.arena_grid = Vector2i(120, 84)
	t.arena_half_cells = Vector2(52.0, 34.0)
	t.wall_texture = wall
	t.arena_rect_pillars = [
		Vector3(-0.62, -0.4, 2.2), Vector3(0.62, -0.4, 2.2), Vector3(-0.62, 0.35, 2.2), Vector3(0.62, 0.35, 2.2),
		Vector3(-0.3, 0.5, 2.0), Vector3(0.3, 0.5, 2.0),
	]
	t.pillar_dark = Color(0.04, 0.04, 0.07)
	t.pillar_mid = Color(0.26, 0.28, 0.36)
	t.pillar_light = Color(0.42, 0.45, 0.56)
	t.pillar_sprites = [
		make_def(props, Rect2(352, 174, 32, 77), Vector2.ZERO),
		make_def(props, Rect2(445, 20, 41, 73), Vector2.ZERO),
	]

	# "Cây" (vật cản cao, lấp vùng ngoài đường): cột đá, cột gãy, tượng, bia mộ, khối tường.
	t.trees = [
		make_def(props, Rect2(352, 174, 32, 77), Vector2(22, 12)),
		make_def(props, Rect2(416, 194, 32, 57), Vector2(22, 12)),
		make_def(props, Rect2(445, 20, 41, 73), Vector2(26, 14)),
		make_def(props, Rect2(227, 9, 26, 52), Vector2(20, 12)),
		make_def(wall, Rect2(48, 304, 32, 32), Vector2(32, 26)),
		make_def(wall, Rect2(144, 304, 32, 32), Vector2(32, 26)),
	]
	# "Bụi" (vật cản thấp): thùng, hòm, bình, đá tảng.
	t.bushes = [
		make_def(props, Rect2(160, 18, 32, 46), Vector2(26, 14)),
		make_def(props, Rect2(162, 153, 28, 36), Vector2(24, 14)),
		make_def(props, Rect2(164, 288, 25, 27), Vector2(18, 10)),
		make_def(props, Rect2(3, 430, 57, 44), Vector2(44, 18)),
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.5),
		make_def(props, Rect2(96, 30, 32, 31), Vector2(28, 12)),
	]
	t.rocks = [
		make_def(props, Rect2(3, 430, 57, 44), Vector2(44, 18)),
		make_def(rocks_tex, Rect2(131, 19, 26, 27), Vector2(30, 14), Vector2i(1, 1), 1.6),
		make_def(rocks_tex, Rect2(161, 17, 31, 14), Vector2(38, 12), Vector2i(1, 1), 1.5),
		make_def(rocks_tex, Rect2(98, 19, 28, 43), Vector2(30, 16), Vector2i(1, 1), 1.5),
	]
	# Tàn tích: đúng thứ tự mà MapGenerator dùng (cùng vùng cắt với bộ mặc định, vì đều lấy từ TX Props).
	t.ruins = [
		make_def(props, Rect2(224, 300, 34, 46), Vector2(22, 12)),
		make_def(props, Rect2(222, 236, 36, 48), Vector2(24, 12)),
		make_def(props, Rect2(442, 18, 44, 80), Vector2(26, 14)),
		make_def(props, Rect2(350, 170, 38, 82), Vector2(28, 16)),
		make_def(props, Rect2(414, 192, 38, 60), Vector2(28, 16)),
		make_def(props, Rect2(288, 16, 60, 48), Vector2(56, 18), Vector2i(2, 1)),
		make_def(props, Rect2(160, 18, 34, 48), Vector2(28, 14)),
		make_def(props, Rect2(160, 152, 30, 40), Vector2(24, 14)),
	]
	# Trang trí không va chạm: bình, biển, đá nhỏ.
	t.decor = [
		make_def(props, Rect2(165, 217, 21, 34), Vector2.ZERO),
		make_def(props, Rect2(164, 348, 22, 32), Vector2.ZERO),
		make_def(props, Rect2(99, 160, 27, 32), Vector2.ZERO),
		make_def(rocks_tex, Rect2(161, 17, 31, 14), Vector2.ZERO, Vector2i(1, 1), 0.8),
		make_def(rocks_tex, Rect2(160, 63, 16, 14), Vector2.ZERO, Vector2i(1, 1), 1.4),
		make_def(rocks_tex, Rect2(144, 62, 16, 14), Vector2.ZERO, Vector2i(1, 1), 1.4),
	]
	return t


static func _load_pixel_art(file_name: String) -> Texture2D:
	var path := PIXEL_ART_ROOT + file_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
