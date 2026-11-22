class_name MapGenerator
extends Node2D
## Sinh bản đồ ngẫu nhiên. Hai kiểu map (Layout):
##   EXPLORE    : map khám phá RỘNG, sinh kiểu BSP (chia nhỏ không gian):
##                - "Phòng" = bãi cỏ để chiến đấu, rải ít đá/tàn tích.
##                - "Đường đi" = hành lang đá UỐN LƯỢN nối các phòng, có vòng nối thêm, nhánh cụt có quảng trường nhỏ,
##                  mép đường lởm chởm, đá lát rải trong phòng, và đồ vật (bia mộ, cột, thùng...) dọc đường.
##                - Cây RẤT THƯA (mọc theo cụm), viền map là hàng cây dày.
##                - "Quảng trường cổng Boss" = phòng xa điểm xuất phát nhất, lát đá, có cột đá bao quanh và BossPortal ở giữa.
##   BOSS_ARENA : đấu trường tròn sinh bằng code cho trận Boss.
## Cả hai quy về MỘT lưới ô (_blocked) để dùng chung: tìm vùng Player tới được, chọn ô spawn, bản đồ hướng đi cho Enemy.
## API công khai giữ nguyên (generate, get_spawn_position, is_spawnable...) nên Main/EnemySpawner dùng như cũ.

## Phát ra khi bản đồ đã sinh xong. Các hệ thống khác (Player, Spawner) chờ tín hiệu này.
signal map_ready

enum Layout { EXPLORE, BOSS_ARENA }
enum Cell { FOREST, ROOM, PATH, PLAZA }
enum BgMode { NONE, ARENA }

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
## Giá trị trả về của get_spawn_position() khi không tìm được vị trí hợp lệ.
const NO_SPAWN: Vector2 = Vector2.INF
## Số ô chặn giữ lại quanh mỗi ô trống khi dựng tường va chạm của đấu trường.
const WALL_MARGIN_CELLS: int = 3
## Bản đồ hướng đi cho Enemy: loang tối đa bấy nhiêu bước từ vị trí Player, cập nhật tối đa mỗi FLOW_INTERVAL giây.
const FLOW_RADIUS_STEPS: int = 400
const FLOW_INTERVAL: float = 0.2

# ---------------------------------------------------------------- Inspector
@export_group("Kích thước bản đồ")
## Số ô theo chiều ngang (bản cũ 48).
@export var map_width: int = 96
## Số ô theo chiều dọc (bản cũ 32).
@export var map_height: int = 64
## Kích thước 1 ô (pixel). Bộ asset dùng 32.
@export var tile_size: int = 32

@export_group("Seed")
## Bật = mỗi lần chạy một map khác nhau. Tắt = dùng Fixed Seed (để debug).
@export var use_random_seed: bool = true
@export var fixed_seed: int = 12345

@export_group("Phòng")
## Cạnh nhỏ nhất của một phòng (ô). Phòng càng lớn càng dễ né đòn.
@export var min_room_size: int = 10
## Khoảng đệm giữa phòng và rìa vùng chia (ô). Càng lớn thì giữa các phòng càng có nhiều đất trống cho nhánh đường và cây.
@export var room_margin: int = 4
## Vùng chia nhỏ hơn mức này có thể dừng chia sớm (map ít phòng hơn).
@export var max_leaf_size: int = 44
## Phòng nhỏ hơn vùng của nó tối đa bấy nhiêu ô (càng lớn thì kích thước phòng càng đa dạng).
@export var room_size_variance: int = 10

@export_group("Đường đi")
## Độ rộng đường chính (ô). Nên >= 3 vì nhân vật khá to.
@export var corridor_width: int = 3
## Số đường nối thêm giữa các phòng để tạo vòng (đỡ bí đường).
@export var extra_corridors: int = 3
## Độ uốn lượn của đường (0 = thẳng kiểu chữ L, 1 = rất ngoằn ngoèo).
@export_range(0.0, 1.0) var path_winding: float = 0.65
## Độ dài mỗi đoạn thẳng của đường uốn lượn (ô).
@export var winding_segment_min: int = 3
@export var winding_segment_max: int = 8
## Xác suất mép đường lan thêm một ô đá ra cỏ (làm mép lởm chởm tự nhiên).
@export_range(0.0, 0.6) var path_edge_roughness: float = 0.15
## Số nhánh đường cụt, mỗi nhánh kết thúc ở một quảng trường nhỏ có tượng/bia mộ.
@export var side_branches: int = 10
@export var branch_length_min: int = 6
@export var branch_length_max: int = 14
## Số lần thử đặt mỗi nhánh (nhánh cần một dải đất trống đủ rộng nên có thể phải thử nhiều lần).
@export var branch_attempts: int = 60
## Số mảng đá lát rải trong mỗi phòng (tối đa).
@export var stone_patches_per_room: int = 2
## Mật độ đồ vật dọc đường (bia mộ, cột, thùng...) so với số ô đường.
@export_range(0.0, 0.2) var path_prop_density: float = 0.025

@export_group("Cây và vật cản")
## Mật độ cây/bụi ở vùng đất ngoài phòng và đường (0 = trống). Bản cũ là 0.75.
@export_range(0.0, 1.0) var tree_density: float = 0.08
## Ngưỡng nhiễu để cây mọc thành cụm: càng cao thì càng ít cụm.
@export_range(-1.0, 1.0) var tree_clump_threshold: float = 0.15
## Mật độ vật cản (đá, tàn tích, bụi) rải trong phòng. (Đã đổi tên từ room_obstacle_density để giá trị cũ ghi đè trong Main.tscn không còn tác dụng.)
@export_range(0.0, 0.3) var room_obstacle_ratio: float = 0.05
## Mật độ cỏ trang trí (không có va chạm).
@export_range(0.0, 0.3) var grass_decor_density: float = 0.05
## Bán kính (ô) quanh điểm xuất phát được giữ trống hoàn toàn.
@export var start_clear_radius: int = 4
## Cho phép tối đa bấy nhiêu ô trống bị cô lập (mảng nhỏ kẹt giữa vật cản) mà map vẫn coi là hợp lệ.
@export var max_unreachable_cells: int = 60

@export_group("Cổng Boss")
## Bán kính quảng trường lát đá quanh cổng (ô).
@export var plaza_radius: int = 4
## Enemy và vật phẩm không xuất hiện trong bán kính này quanh cổng Boss (pixel).
@export var portal_no_spawn_radius: float = 260.0

@export_group("Phòng Boss")
@export var arena_cell_size: float = 16.0
@export var arena_grid_size: Vector2i = Vector2i(80, 80)
## Bán kính đấu trường tính theo ô.
@export var arena_radius_cells: float = 33.0

@export_group("Asset (kéo thả nếu đường dẫn thay đổi)")
@export var grass_texture: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Tileset Grass.png")
@export var stone_texture: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Tileset Stone Ground.png")
@export var plant_texture: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Plant.png")
@export var props_texture: Texture2D = preload("res://Assets/Enviroments/Pixel Art Top Down - Basic v1.2.3/Texture/TX Props.png")
## Toạ độ ô (cột, hàng) trong ảnh TX Tileset Grass dùng làm nền cỏ. Mỗi ô 32x32.
@export var grass_tiles: Array[Vector2i] = [Vector2i(1, 2)]
## Toạ độ ô trong ảnh TX Tileset Stone Ground dùng làm đường đá.
@export var stone_tile: Vector2i = Vector2i(1, 1)

@export_group("Điều khiển")
## Chỉ cần bật khi chạy riêng scene này bằng F6. Khi chạy trong Main, Main tự gọi generate().
@export var generate_on_ready: bool = false

@export_group("Debug")
## Vẽ phủ lên map: phòng (xanh dương), đường (vàng), quảng trường cổng (tím), điểm xuất phát (xanh lá). Phím F3 để bật/tắt.
@export var debug_draw: bool = false

# ---------------------------------------------------------------- Kết quả (chỉ đọc từ bên ngoài)
var current_seed: int = 0
var current_layout: Layout = Layout.EXPLORE
var map_valid: bool = false
var unreachable_cells: int = 0
## Thời gian sinh map lần gần nhất (mili-giây), để đo hiệu năng (DebugStats hiển thị).
var last_generation_ms: float = 0.0

# ---------------------------------------------------------------- Biến nội bộ
class Leaf:
	var rect: Rect2i
	var left: Leaf
	var right: Leaf
	var room: Rect2i = Rect2i()
	var has_room: bool = false

	func _init(r: Rect2i) -> void:
		rect = r


var rng := RandomNumberGenerator.new()
var _spawn_rng := RandomNumberGenerator.new()

var _ground: TileMapLayer
var _decor_root: Node2D
var _entities: Node2D
var _overlay: Node2D
var _bg: Node2D
var _bg_mode: BgMode = BgMode.NONE
var _walls: StaticBody2D = null
var _boundary: StaticBody2D = null
var _grass_source_id: int = 0
var _stone_source_id: int = 0

var _grid_w: int = 0
var _grid_h: int = 0
var _cell: float = 32.0
var _map_size: Vector2 = Vector2.ZERO
var _cells: PackedByteArray = PackedByteArray()      # loại ô (Cell), chỉ dùng ở layout EXPLORE
var _blocked: PackedByteArray = PackedByteArray()    # 1 = có vật cản
var _clear: PackedByteArray = PackedByteArray()      # 1 = ô và cả 8 ô quanh nó đều không vật cản (Player đứng được)
var _reachable: PackedByteArray = PackedByteArray()  # 1 = nối được với điểm xuất phát
var _rooms: Array[Rect2i] = []
var _branch_ends: Array[Vector2i] = []
var _start_cell: Vector2i = Vector2i.ZERO
var _portal_room: Rect2i = Rect2i()
var _portal_cell: Vector2i = Vector2i.ZERO
var _portal: BossPortal = null
var _portal_local: Vector2 = Vector2.ZERO
var _spawn_cells: Array[Vector2i] = []
var _arena_center: Vector2 = Vector2.ZERO
var _arena_radius_px: float = 0.0
var _arena_half_px: Vector2 = Vector2.ZERO  # khác ZERO = đấu trường chữ nhật (nửa rộng, nửa cao, pixel)
var _arena_pillars: Array[Vector2] = []
var _arena_pillar_radii: Array[float] = []  # bán kính từng vật cản (đơn vị ô), cùng chỉ số với _arena_pillars
var _wall_rect_count: int = 0
var _extra_nodes: Array[Node] = []  # node do bên ngoài thêm vào map (cổng thoát...), được dọn khi sinh map mới

var _flow_dist: PackedInt32Array = PackedInt32Array()  # số bước tới ô của Player; -1 = chưa loang tới
var _flow_cell: Vector2i = Vector2i(-1, -1)
var _flow_timer: float = 0.0

## Giao diện hiện tại (null = bộ mặc định). Đổi bằng set_theme() TRƯỚC khi gọi generate().
var theme: MapTheme = null
var _tree_defs: Array = []
var _bush_defs: Array = []
var _rock_defs: Array = []
var _ruin_defs: Array = []
var _decor_defs: Array = []


# ================================================================ Vòng đời
func _ready() -> void:
	_setup_nodes()
	if generate_on_ready or get_parent() == get_tree().root:
		generate()


## Cập nhật bản đồ hướng đi quanh Player (chỉ khi có Enemy và Player đã sang ô khác).
func _physics_process(delta: float) -> void:
	if _clear.is_empty():
		return
	_flow_timer -= delta
	if _flow_timer > 0.0:
		return
	_flow_timer = FLOW_INTERVAL
	if get_tree().get_nodes_in_group("enemies").is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cell := _world_to_cell(player.global_position)
	if cell != _flow_cell:
		_rebuild_flow(cell)


# ================================================================ API công khai
## Sinh bản đồ mới (mặc định là map khám phá). Phát tín hiệu map_ready khi xong.
func generate(layout: Layout = Layout.EXPLORE) -> void:
	var started_usec := Time.get_ticks_usec()
	_setup_nodes()
	current_layout = layout
	_clear_previous()
	match layout:
		Layout.EXPLORE:
			for attempt in 6:
				if use_random_seed:
					rng.randomize()
				else:
					rng.seed = fixed_seed
				current_seed = rng.seed
				_spawn_rng.seed = current_seed + 1  # cùng seed map -> cùng chuỗi vị trí spawn (dễ debug)
				_generate_explore_once()
				if map_valid or not use_random_seed:
					break
				_clear_previous()
		Layout.BOSS_ARENA:
			_spawn_rng.randomize()
			_build_arena()
			_finalize_grid()
	_overlay.queue_redraw()
	_bg.queue_redraw()
	last_generation_ms = float(Time.get_ticks_usec() - started_usec) / 1000.0
	print("[MapGenerator] layout=%s | seed=%d | lưới=%dx%d | phòng=%d | ô spawn=%d | ô không tới được=%d | hợp lệ=%s | %.0f ms" % [
		Layout.keys()[layout], current_seed, _grid_w, _grid_h, _rooms.size(), _spawn_cells.size(), unreachable_cells, str(map_valid), last_generation_ms])
	map_ready.emit()


## Đổi giao diện map (ảnh nền, đường, cây, đá, màu đấu trường). null = giao diện mặc định. Có hiệu lực ở lần generate() kế tiếp.
func set_theme(new_theme: MapTheme) -> void:
	theme = new_theme
	_setup_nodes()
	_ground.tile_set = _build_tile_set()
	# Ô của theme có thể nhỏ hơn ô map (16 px so với 32 px): phóng cả lớp nền để mỗi ô luôn phủ đúng một ô map.
	var px := tile_size if theme == null else theme.tile_px
	_ground.scale = Vector2.ONE * float(tile_size) / float(maxi(px, 1))
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_defs()
	_bg.queue_redraw()


func get_layout() -> Layout:
	return current_layout


## Vị trí (toạ độ thế giới) để đặt Player.
func get_player_start_position() -> Vector2:
	return to_global(_cell_center(_start_cell))


## Node cha dùng chung cho Player, Enemy và vật cản (đã bật Y-Sort để che khuất đúng).
func get_entities_root() -> Node2D:
	return _entities


func get_map_pixel_size() -> Vector2:
	return _map_size


## Ảnh thu nhỏ của map cho mini map: mỗi ô lưới = 1 pixel (ô có vật cản trong suốt tối, ô đi được sáng, đường đi vàng, quảng trường tím).
## Toạ độ thế giới -> pixel: to_local(vị trí) / get_minimap_cell_size(). Trả về null nếu map chưa sẵn sàng.
func get_minimap_image() -> Image:
	var count := _grid_w * _grid_h
	if _grid_w <= 0 or _grid_h <= 0 or _blocked.size() != count:
		return null
	var img := Image.create(_grid_w, _grid_h, false, Image.FORMAT_RGBA8)
	var has_types := _cells.size() == count and current_layout == Layout.EXPLORE
	var wall := Color(0.07, 0.09, 0.13, 0.85)
	var floor_color := Color(0.30, 0.44, 0.40, 0.95) if current_layout == Layout.EXPLORE else Color(0.36, 0.38, 0.55, 0.95)
	for y in _grid_h:
		for x in _grid_w:
			var i := y * _grid_w + x
			var c := wall
			if _blocked[i] == 0:
				c = floor_color
				if has_types:
					match _cells[i]:
						Cell.PATH:
							c = Color(0.78, 0.72, 0.48, 0.98)
						Cell.PLAZA:
							c = Color(0.68, 0.45, 0.88, 0.98)
			img.set_pixel(x, y, c)
	return img


func get_minimap_cell_size() -> float:
	return _cell


## Cổng dịch chuyển tới phòng Boss (chỉ có ở map khám phá, null ở phòng Boss).
func get_portal() -> BossPortal:
	return _portal


## Tâm đấu trường (toạ độ thế giới), nơi Boss sẽ xuất hiện (Phase 7). Chỉ có ý nghĩa ở layout BOSS_ARENA.
func get_boss_spawn_position() -> Vector2:
	return to_global(_arena_center)


## Chọn ngẫu nhiên một vị trí (toạ độ thế giới) hợp lệ để spawn Enemy/vật phẩm:
## ô trống, nối được với điểm xuất phát của Player, cách from_pos trong khoảng [min_distance, max_distance] pixel.
## Trả về NO_SPAWN nếu không có vị trí nào thoả điều kiện.
func get_spawn_position(from_pos: Vector2, min_distance: float, max_distance: float = INF) -> Vector2:
	if _spawn_cells.is_empty():
		return NO_SPAWN
	var min_sq := min_distance * min_distance
	var max_sq := max_distance * max_distance
	# Thử ngẫu nhiên vài lần trước (nhanh)...
	for attempt in 40:
		var p := to_global(_cell_center(_spawn_cells[_spawn_rng.randi() % _spawn_cells.size()]))
		var d := from_pos.distance_squared_to(p)
		if d >= min_sq and d <= max_sq:
			return p
	# ...không được thì lọc toàn bộ danh sách (chậm hơn nhưng chắc chắn).
	var candidates: Array[Vector2] = []
	for c in _spawn_cells:
		var p := to_global(_cell_center(c))
		var d := from_pos.distance_squared_to(p)
		if d >= min_sq and d <= max_sq:
			candidates.append(p)
	if candidates.is_empty():
		return NO_SPAWN
	return candidates[_spawn_rng.randi() % candidates.size()]


## Vị trí (toạ độ thế giới) có phải ô Player đi tới được (không gần vật cản) không.
func is_spawnable(world_pos: Vector2) -> bool:
	var cell := _world_to_cell(world_pos)
	if not _in_bounds(cell):
		return false
	return _reachable[_idx(cell.x, cell.y)] == 1


func get_spawn_cell_count() -> int:
	return _spawn_cells.size()


## Thêm một node vào map (ví dụ cổng thoát của phòng Boss). Node được đặt ngay trước Entities để vẽ trên nền nhưng dưới nhân vật,
## và tự được giải phóng khi sinh map mới.
func add_world_node(node: Node2D) -> void:
	add_child(node)
	move_child(node, _entities.get_index())
	_extra_nodes.append(node)


## Toạ độ thế giới của một điểm trong đấu trường: angle (radian, -PI/2 = phía bắc) và radius_ratio (0 = tâm, 1 = mép).
func get_arena_point(angle: float, radius_ratio: float) -> Vector2:
	return to_global(_arena_center + Vector2.from_angle(angle) * _arena_radius_px * radius_ratio)


func get_arena_radius() -> float:
	return _arena_radius_px


## Nửa kích thước (pixel) của đấu trường chữ nhật; ZERO nếu đấu trường hình tròn.
func get_arena_half_extents() -> Vector2:
	return _arena_half_px


func toggle_debug_draw() -> void:
	debug_draw = not debug_draw
	_overlay.queue_redraw()


## Hướng (đã chuẩn hóa, toạ độ thế giới) mà Enemy tại world_pos nên đi để vòng qua vật cản tới Player.
## Trả về Vector2.ZERO nếu chưa có dữ liệu.
func get_flow_direction(world_pos: Vector2) -> Vector2:
	if _flow_dist.size() != _grid_w * _grid_h or _flow_cell.x < 0:
		return Vector2.ZERO
	var cell := _world_to_cell(world_pos)
	var own_d := _flow_at(cell.x, cell.y)
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	if own_d >= 0:
		# Ô của Enemy có dữ liệu: chọn ô láng giềng (8 hướng) gần Player hơn; đi chéo chỉ khi 2 ô kề bên cùng thông.
		best_d = own_d
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				if dx != 0 and dy != 0 and (_flow_at(cell.x + dx, cell.y) < 0 or _flow_at(cell.x, cell.y + dy) < 0):
					continue
				var d := _flow_at(cell.x + dx, cell.y + dy)
				if d >= 0 and d < best_d:
					best_d = d
					best = Vector2i(cell.x + dx, cell.y + dy)
	else:
		# Enemy đứng sát vật cản (ô không có dữ liệu): tìm ô có dữ liệu gần nhất trong 5x5 và đi tới đó.
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var d := _flow_at(cell.x + dx, cell.y + dy)
				if d >= 0 and d < best_d:
					best_d = d
					best = Vector2i(cell.x + dx, cell.y + dy)
	if best.x < 0:
		return Vector2.ZERO
	var offset := to_global(_cell_center(best)) - world_pos
	return offset.normalized() if offset.length_squared() > 1.0 else Vector2.ZERO


# ================================================================ Dựng node một lần
func _setup_nodes() -> void:
	if _ground != null:
		return
	add_to_group("map_generator")  # để Enemy tìm được bản đồ hướng đi
	_bg = Node2D.new()
	_bg.name = "Background"
	_bg.z_index = -10
	_bg.draw.connect(_on_bg_draw)
	add_child(_bg)

	_ground = TileMapLayer.new()
	_ground.name = "GroundLayer"
	_ground.tile_set = _build_tile_set()
	add_child(_ground)

	_decor_root = Node2D.new()
	_decor_root.name = "Decor"
	add_child(_decor_root)

	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)

	_overlay = Node2D.new()
	_overlay.name = "DebugOverlay"
	_overlay.z_index = 100
	_overlay.draw.connect(_on_overlay_draw)
	add_child(_overlay)
	_build_defs()


func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	if theme != null:
		ts.tile_size = Vector2i(theme.tile_px, theme.tile_px)
		_grass_source_id = ts.add_source(_make_atlas_source(theme.ground_texture, theme.ground_tiles, theme.tile_px))
		_stone_source_id = ts.add_source(_make_atlas_source(theme.path_texture, theme.path_tiles, theme.tile_px))
		return ts
	ts.tile_size = Vector2i(tile_size, tile_size)
	var grass_coords: Array[Vector2i] = []
	grass_coords.append_array(grass_tiles)
	var stone_coords: Array[Vector2i] = [stone_tile]
	_grass_source_id = ts.add_source(_make_atlas_source(grass_texture, grass_coords, tile_size))
	_stone_source_id = ts.add_source(_make_atlas_source(stone_texture, stone_coords, tile_size))
	return ts


func _make_atlas_source(texture: Texture2D, coords: Array[Vector2i], region_px: int) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = texture
	src.texture_region_size = Vector2i(region_px, region_px)
	for c in coords:
		src.create_tile(c)
	return src


## Dọn dữ liệu của map trước. Player (nhóm "player") được giữ lại; mọi thứ khác trong Entities bị xóa.
func _clear_previous() -> void:
	for body in [_walls, _boundary]:
		if body != null:
			remove_child(body)
			body.queue_free()
	_walls = null
	_boundary = null
	if _portal != null:
		remove_child(_portal)
		_portal.queue_free()
		_portal = null
	for extra in _extra_nodes:
		if is_instance_valid(extra):
			remove_child(extra)
			extra.queue_free()
	_extra_nodes.clear()
	for child in _decor_root.get_children():
		child.queue_free()
	_ground.clear()
	for child in _entities.get_children():
		if child.is_in_group("player"):
			continue
		child.remove_from_group("enemies")  # để bộ đếm Enemy đúng ngay, không chờ cuối frame
		child.remove_from_group("spell_pickups")
		child.queue_free()
	_bg_mode = BgMode.NONE
	_arena_pillars.clear()
	_arena_pillar_radii.clear()
	_arena_half_px = Vector2.ZERO
	_rooms.clear()
	_branch_ends.clear()
	_spawn_cells.clear()
	_cells = PackedByteArray()
	_blocked = PackedByteArray()
	_clear = PackedByteArray()
	_reachable = PackedByteArray()
	_flow_dist = PackedInt32Array()
	_flow_cell = Vector2i(-1, -1)
	_wall_rect_count = 0
	unreachable_cells = 0
	map_valid = false
	_grid_w = 0
	_grid_h = 0


# ================================================================ Định nghĩa vật cản
# Mỗi vật cản: ảnh cắt từ spritesheet (region), vùng va chạm ở CHÂN vật (collision),
# và số ô nó chiếm trên lưới (footprint). Region là toạ độ pixel trong ảnh gốc.
func _build_defs() -> void:
	if theme != null:
		_tree_defs = theme.trees
		_bush_defs = theme.bushes
		_rock_defs = theme.rocks
		_ruin_defs = theme.ruins
		_decor_defs = theme.decor
		return
	_tree_defs = [
		_make_def(plant_texture, Rect2(20, 10, 125, 150), Vector2(14, 10)),
		_make_def(plant_texture, Rect2(156, 10, 108, 150), Vector2(14, 10)),
		_make_def(plant_texture, Rect2(290, 26, 90, 132), Vector2(14, 10)),
	]
	_bush_defs = [
		_make_def(plant_texture, Rect2(32, 194, 32, 26), Vector2(22, 14)),
		_make_def(plant_texture, Rect2(94, 192, 36, 30), Vector2(26, 16)),
		_make_def(plant_texture, Rect2(152, 186, 46, 40), Vector2(32, 18)),
		_make_def(plant_texture, Rect2(212, 180, 54, 50), Vector2(38, 20)),
		_make_def(plant_texture, Rect2(278, 180, 50, 54), Vector2(34, 20)),
		_make_def(plant_texture, Rect2(342, 186, 48, 42), Vector2(34, 18)),
	]
	_rock_defs = [
		_make_def(props_texture, Rect2(0, 426, 66, 48), Vector2(50, 22)),
		_make_def(props_texture, Rect2(160, 478, 32, 34), Vector2(26, 16)),
		_make_def(props_texture, Rect2(128, 484, 34, 28), Vector2(26, 14)),
		_make_def(props_texture, Rect2(64, 486, 30, 26), Vector2(24, 14)),
	]
	# Thứ tự cố định vì code bên dưới tham chiếu theo chỉ số: 0 bia mộ chữ thập, 1 bia mộ, 2 tượng, 3 cột đá,
	# 4 cột đá gãy, 5 ghế đá (2 ô), 6 thùng gỗ, 7 thùng tròn.
	_ruin_defs = [
		_make_def(props_texture, Rect2(224, 300, 34, 46), Vector2(22, 12)),
		_make_def(props_texture, Rect2(222, 236, 36, 48), Vector2(24, 12)),
		_make_def(props_texture, Rect2(442, 18, 44, 80), Vector2(26, 14)),
		_make_def(props_texture, Rect2(350, 170, 38, 82), Vector2(28, 16)),
		_make_def(props_texture, Rect2(414, 192, 38, 60), Vector2(28, 16)),
		_make_def(props_texture, Rect2(288, 16, 60, 48), Vector2(56, 18), Vector2i(2, 1)),
		_make_def(props_texture, Rect2(160, 18, 34, 48), Vector2(28, 14)),
		_make_def(props_texture, Rect2(160, 152, 30, 40), Vector2(24, 14)),
	]
	_decor_defs = [
		_make_def(plant_texture, Rect2(6, 392, 24, 16), Vector2.ZERO),
		_make_def(plant_texture, Rect2(38, 392, 24, 16), Vector2.ZERO),
		_make_def(plant_texture, Rect2(70, 392, 24, 16), Vector2.ZERO),
		_make_def(plant_texture, Rect2(100, 392, 22, 16), Vector2.ZERO),
		_make_def(plant_texture, Rect2(6, 424, 24, 16), Vector2.ZERO),
		_make_def(plant_texture, Rect2(38, 424, 24, 16), Vector2.ZERO),
		_make_def(plant_texture, Rect2(70, 424, 24, 16), Vector2.ZERO),
		_make_def(plant_texture, Rect2(100, 424, 22, 16), Vector2.ZERO),
	]


func _make_def(tex: Texture2D, region: Rect2, collision: Vector2, footprint: Vector2i = Vector2i(1, 1)) -> Dictionary:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	var shape: RectangleShape2D = null
	if collision.x > 0.0 and collision.y > 0.0:
		shape = RectangleShape2D.new()
		shape.size = collision
	return {"atlas": atlas, "region": region, "shape": shape, "collision": collision, "footprint": footprint, "scale": Vector2.ONE}


# ================================================================ Sinh map khám phá
func _generate_explore_once() -> void:
	_reset_explore()
	var root_leaf := Leaf.new(Rect2i(0, 0, _grid_w, _grid_h))
	_split(root_leaf)
	_make_rooms(root_leaf)
	_connect(root_leaf)
	_add_extra_corridors()
	_choose_start()
	_choose_portal_room()
	_carve_plaza()
	_add_side_branches()
	_scatter_stone_patches()
	_roughen_paths()
	_paint_ground()
	_scatter_room_obstacles()
	_place_path_props()
	_place_branch_props()
	_place_portal_props()
	_fill_forest()
	_scatter_decor()
	_build_boundary()
	_finalize_explore()


func _reset_explore() -> void:
	_grid_w = map_width
	_grid_h = map_height
	_cell = float(tile_size)
	_map_size = Vector2(_grid_w, _grid_h) * _cell
	_rooms.clear()
	_branch_ends.clear()
	var total := _grid_w * _grid_h
	_cells.resize(total)
	_cells.fill(Cell.FOREST)
	_blocked.resize(total)
	_blocked.fill(0)
	_reachable.resize(total)
	_reachable.fill(0)
	_clear.resize(total)
	_clear.fill(0)


# ---- BSP: chia đôi vùng liên tục cho tới khi vùng nhỏ
func _split(leaf: Leaf) -> void:
	var min_leaf := min_room_size + room_margin * 2
	var can_x := leaf.rect.size.x >= min_leaf * 2
	var can_y := leaf.rect.size.y >= min_leaf * 2
	if not can_x and not can_y:
		return
	if leaf.rect.size.x <= max_leaf_size and leaf.rect.size.y <= max_leaf_size and rng.randf() < 0.35:
		return

	var split_x: bool
	if can_x and can_y:
		split_x = rng.randf() < float(leaf.rect.size.x) / float(leaf.rect.size.x + leaf.rect.size.y)
	else:
		split_x = can_x

	var pos := leaf.rect.position
	var size := leaf.rect.size
	if split_x:
		var cut := rng.randi_range(min_leaf, size.x - min_leaf)
		leaf.left = Leaf.new(Rect2i(pos, Vector2i(cut, size.y)))
		leaf.right = Leaf.new(Rect2i(pos + Vector2i(cut, 0), Vector2i(size.x - cut, size.y)))
	else:
		var cut := rng.randi_range(min_leaf, size.y - min_leaf)
		leaf.left = Leaf.new(Rect2i(pos, Vector2i(size.x, cut)))
		leaf.right = Leaf.new(Rect2i(pos + Vector2i(0, cut), Vector2i(size.x, size.y - cut)))
	_split(leaf.left)
	_split(leaf.right)


# ---- Tạo một phòng trong mỗi vùng lá
func _make_rooms(leaf: Leaf) -> void:
	if leaf.left != null:
		_make_rooms(leaf.left)
		_make_rooms(leaf.right)
		return
	var max_w := leaf.rect.size.x - room_margin * 2
	var max_h := leaf.rect.size.y - room_margin * 2
	var w := rng.randi_range(maxi(min_room_size, max_w - room_size_variance), max_w)
	var h := rng.randi_range(maxi(min_room_size, max_h - room_size_variance), max_h)
	var x := leaf.rect.position.x + room_margin + rng.randi_range(0, max_w - w)
	var y := leaf.rect.position.y + room_margin + rng.randi_range(0, max_h - h)
	leaf.room = Rect2i(x, y, w, h)
	leaf.has_room = true
	_rooms.append(leaf.room)
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_cells[_idx(xx, yy)] = Cell.ROOM


# ---- Nối hai nhánh cây BSP bằng một đường uốn lượn. Trả về 1 phòng đại diện của nhánh.
func _connect(leaf: Leaf) -> Rect2i:
	if leaf.left == null:
		return leaf.room
	var a := _connect(leaf.left)
	var b := _connect(leaf.right)
	_carve_winding(a.get_center(), b.get_center(), _random_corridor_width())
	return a if rng.randf() < 0.5 else b


func _add_extra_corridors() -> void:
	if _rooms.size() < 3:
		return
	for i in extra_corridors:
		var a := rng.randi() % _rooms.size()
		var b := rng.randi() % _rooms.size()
		if a == b:
			continue
		_carve_winding(_rooms[a].get_center(), _rooms[b].get_center(), _random_corridor_width())


## Đa số đường rộng corridor_width; thỉnh thoảng rộng hơn 1 ô cho có nhịp.
func _random_corridor_width() -> int:
	return corridor_width + (1 if rng.randf() < 0.2 else 0)


## Đào đường từ a tới b: các đoạn thẳng xen kẽ ngang/dọc với độ dài ngẫu nhiên, thỉnh thoảng lệch sang bên 1-2 ô.
## Luôn tới được b: nếu hết số bước cho phép thì nối nốt bằng đường chữ L.
func _carve_winding(a: Vector2i, b: Vector2i, width: int) -> void:
	var pos := a
	_stamp_path(pos, width)
	var horizontal := rng.randf() < 0.5
	var guard := 0
	while pos != b and guard < 300:
		guard += 1
		var remain := b - pos
		if horizontal and remain.x == 0:
			horizontal = false
		elif not horizontal and remain.y == 0:
			horizontal = true
		# path_winding = 0: một đoạn dài tới hết -> đường chữ L; càng cao càng nhiều đoạn ngắn.
		var seg := 999 if path_winding <= 0.0 else rng.randi_range(winding_segment_min, winding_segment_max)
		if horizontal:
			var step := signi(remain.x)
			for i in mini(seg, absi(remain.x)):
				pos.x += step
				_stamp_path(pos, width)
		else:
			var step := signi(remain.y)
			for i in mini(seg, absi(remain.y)):
				pos.y += step
				_stamp_path(pos, width)
		if pos != b and rng.randf() < path_winding:
			# Lệch sang bên 1-2 ô (vuông góc hướng vừa đi) rồi mới đổi trục.
			var side := Vector2i(0, 1) if horizontal else Vector2i(1, 0)
			var amount := rng.randi_range(1, 2) * (1 if rng.randf() < 0.5 else -1)
			var target := _clamp_cell(pos + side * amount)
			while pos != target:
				pos += Vector2i(signi(target.x - pos.x), signi(target.y - pos.y))
				_stamp_path(pos, width)
		horizontal = not horizontal
	if pos != b:
		_carve_straight(pos, Vector2i(b.x, pos.y), width)
		_carve_straight(Vector2i(b.x, pos.y), b, width)


func _carve_straight(p_from: Vector2i, p_to: Vector2i, width: int) -> void:
	var pos := p_from
	_stamp_path(pos, width)
	while pos != p_to:
		pos += Vector2i(signi(p_to.x - pos.x), signi(p_to.y - pos.y))
		_stamp_path(pos, width)


## Đánh dấu hình vuông width x width quanh center là đường đá. Không đè lên quảng trường cổng và không lát đá lên cỏ trong phòng
## (đường vẫn "đi xuyên" phòng vì phòng là đất đi được; phòng chỉ có các mảng đá lát nhỏ).
func _stamp_path(center: Vector2i, width: int) -> void:
	var offset := int(width * 0.5)
	for y in range(center.y - offset, center.y - offset + width):
		for x in range(center.x - offset, center.x - offset + width):
			# giữ lại 1 ô viền ngoài cùng luôn là rừng
			if x < 1 or y < 1 or x >= _grid_w - 1 or y >= _grid_h - 1:
				continue
			var i := _idx(x, y)
			if _cells[i] != Cell.PLAZA and _cells[i] != Cell.ROOM:
				_cells[i] = Cell.PATH


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 3, _grid_w - 4), clampi(c.y, 3, _grid_h - 4))


func _choose_start() -> void:
	var room := _rooms[rng.randi() % _rooms.size()]
	_start_cell = room.get_center()


# ---- Quảng trường cổng Boss: phòng đủ rộng và xa điểm xuất phát nhất
func _choose_portal_room() -> void:
	var min_side := plaza_radius * 2 + 3
	var best_dist := -1.0
	_portal_room = _rooms[0]
	for room in _rooms:
		if room.size.x < min_side or room.size.y < min_side:
			continue
		var d := Vector2(room.get_center() - _start_cell).length()
		if d > best_dist:
			best_dist = d
			_portal_room = room
	if best_dist < 0.0:  # không phòng nào đủ rộng: lấy phòng lớn nhất khác phòng xuất phát
		var best_area := -1
		for room in _rooms:
			if room.get_center() != _start_cell and room.get_area() > best_area:
				best_area = room.get_area()
				_portal_room = room
	_portal_cell = _portal_room.get_center()


func _carve_plaza() -> void:
	var limit := plaza_radius * plaza_radius + 4  # +4 để 4 ô chéo (±3, ±3) nằm trong quảng trường
	for dy in range(-plaza_radius - 1, plaza_radius + 2):
		for dx in range(-plaza_radius - 1, plaza_radius + 2):
			if dx * dx + dy * dy > limit:
				continue
			var p := _portal_cell + Vector2i(dx, dy)
			if _in_bounds(p):
				_cells[_idx(p.x, p.y)] = Cell.PLAZA


# ---- Nhánh đường cụt: đi từ một ô đường vào vùng đất trống, kết thúc ở quảng trường nhỏ 5x5
func _add_side_branches() -> void:
	var path_cells := _collect_cells(Cell.PATH)
	if path_cells.is_empty():
		return
	for i in side_branches:
		for attempt in branch_attempts:
			var s := path_cells[rng.randi() % path_cells.size()]
			var dir := DIRS[rng.randi() % DIRS.size()]
			# Ô đầu tiên nằm NGOÀI đường theo hướng dir (đường rộng 3-4 ô nên có thể phải bước vài ô).
			var out := s
			var steps := 0
			while _in_bounds(out) and _cells[_idx(out.x, out.y)] == Cell.PATH and steps < 6:
				out += dir
				steps += 1
			if steps >= 6:
				continue
			var end := out + dir * rng.randi_range(branch_length_min, branch_length_max)
			if end.x < 6 or end.y < 6 or end.x >= _grid_w - 6 or end.y >= _grid_h - 6:
				continue
			# Dải đất cần toàn là đất trống (không đè lên phòng hay đường khác). Không nới ngược về phía đường xuất phát.
			if not _rect_all_forest(_branch_band(out, end, dir)):
				continue
			_carve_winding(s, end, 2)
			_stamp_path(end, 5)
			_branch_ends.append(end)
			break


## Dải kiểm tra của một nhánh: từ out tới end, rộng thêm 3 ô hai bên và 3 ô phía sau điểm cuối (chừa chỗ cho quảng trường 5x5 và độ lệch của đường uốn lượn).
func _branch_band(out: Vector2i, end: Vector2i, dir: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(out.x, end.x), mini(out.y, end.y))
	var hi := Vector2i(maxi(out.x, end.x), maxi(out.y, end.y))
	if dir.x != 0:
		lo.y -= 3
		hi.y += 3
		if dir.x > 0:
			hi.x += 3
		else:
			lo.x -= 3
	else:
		lo.x -= 3
		hi.x += 3
		if dir.y > 0:
			hi.y += 3
		else:
			lo.y -= 3
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _rect_all_forest(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _in_bounds(Vector2i(x, y)) or _cells[_idx(x, y)] != Cell.FOREST:
				return false
	return true


func _collect_cells(kind: Cell) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in _grid_h:
		for x in _grid_w:
			if _cells[_idx(x, y)] == kind:
				out.append(Vector2i(x, y))
	return out


# ---- Mảng đá lát rải trong phòng (chỉ để cho đẹp, không chặn đường)
func _scatter_stone_patches() -> void:
	for room in _rooms:
		if room == _portal_room:
			continue
		var count := rng.randi_range(0, stone_patches_per_room)
		for k in count:
			var center := Vector2(
				rng.randi_range(room.position.x + 2, room.end.x - 3),
				rng.randi_range(room.position.y + 2, room.end.y - 3))
			var radius := rng.randf_range(1.4, 2.6)
			for y in range(int(center.y - 3), int(center.y + 4)):
				for x in range(int(center.x - 3), int(center.x + 4)):
					var p := Vector2i(x, y)
					if _in_bounds(p) and Vector2(x, y).distance_to(center) <= radius + rng.randf_range(-0.4, 0.4) and _cells[_idx(x, y)] == Cell.ROOM:
						_cells[_idx(x, y)] = Cell.PATH


# ---- Làm mép đường lởm chởm: ô cỏ kề đường có xác suất trở thành đá
func _roughen_paths() -> void:
	var convert: Array[int] = []
	for y in range(2, _grid_h - 2):
		for x in range(2, _grid_w - 2):
			if _cells[_idx(x, y)] != Cell.PATH:
				continue
			for d in DIRS:
				var n := Vector2i(x, y) + d
				var ni := _idx(n.x, n.y)
				if n.x < 2 or n.y < 2 or n.x >= _grid_w - 2 or n.y >= _grid_h - 2:
					continue
				if _cells[ni] == Cell.FOREST and rng.randf() < path_edge_roughness:
					convert.append(ni)
	for ni in convert:
		_cells[ni] = Cell.PATH


# ---- Vẽ nền: cỏ khắp nơi, đá ở ô đường và quảng trường
func _paint_ground() -> void:
	for y in _grid_h:
		for x in _grid_w:
			var pos := Vector2i(x, y)
			var kind := _cells[_idx(x, y)]
			if theme != null:
				var tiles: Array[Vector2i] = theme.path_tiles if (kind == Cell.PATH or kind == Cell.PLAZA) else theme.ground_tiles
				var source := _stone_source_id if (kind == Cell.PATH or kind == Cell.PLAZA) else _grass_source_id
				_ground.set_cell(pos, source, tiles[rng.randi() % tiles.size()])
			elif kind == Cell.PATH or kind == Cell.PLAZA:
				_ground.set_cell(pos, _stone_source_id, stone_tile)
			else:
				_ground.set_cell(pos, _grass_source_id, grass_tiles[rng.randi() % grass_tiles.size()])


# ---- Rải vật cản trong phòng: cách nhau >= 2 ô, chừa viền 2 ô, tránh đường đi, điểm xuất phát và quảng trường cổng.
# Nhờ quy tắc khoảng cách này, vật cản trong phòng KHÔNG THỂ chặn kín đường.
func _scatter_room_obstacles() -> void:
	var pool: Array = _rock_defs + _rock_defs + _ruin_defs + _bush_defs
	for room in _rooms:
		var inner := room.grow(-2)
		if inner.size.x < 1 or inner.size.y < 1:
			continue
		var want := int(round(inner.get_area() * room_obstacle_ratio))
		var attempts := want * 8
		var placed := 0
		while placed < want and attempts > 0:
			attempts -= 1
			var def: Dictionary = pool[rng.randi() % pool.size()]
			var fp: Vector2i = def["footprint"]
			if inner.size.x < fp.x or inner.size.y < fp.y:
				continue
			var cell := Vector2i(
				rng.randi_range(inner.position.x, inner.end.x - fp.x),
				rng.randi_range(inner.position.y, inner.end.y - fp.y))
			if not _can_place_room_obstacle(cell, fp):
				continue
			_spawn_obstacle(def, cell)
			_mark_blocked(cell, fp)
			placed += 1


func _can_place_room_obstacle(cell: Vector2i, fp: Vector2i) -> bool:
	var body := Rect2i(cell, fp)
	if _in_special_zone(body):
		return false
	var area := body.grow(2)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var p := Vector2i(x, y)
			if not _in_bounds(p):
				continue
			var i := _idx(x, y)
			if _blocked[i] == 1:
				return false
			if body.has_point(p) and _cells[i] != Cell.ROOM:
				return false
	return true


## Vùng cấm đặt vật cản: quanh điểm xuất phát và quanh quảng trường cổng Boss.
func _in_special_zone(body: Rect2i) -> bool:
	var r := start_clear_radius
	if body.intersects(Rect2i(_start_cell - Vector2i(r, r), Vector2i(r * 2 + 1, r * 2 + 1))):
		return true
	var pr := plaza_radius + 3
	return body.intersects(Rect2i(_portal_cell - Vector2i(pr, pr), Vector2i(pr * 2 + 1, pr * 2 + 1)))


# ---- Đồ vật dọc đường: đặt trên ô cỏ NGAY SÁT đường (không nằm trên đường) nên không bao giờ chặn đường
func _place_path_props() -> void:
	var path_cells := _collect_cells(Cell.PATH)
	if path_cells.is_empty():
		return
	var pool: Array = [_ruin_defs[0], _ruin_defs[1], _ruin_defs[3], _ruin_defs[4], _ruin_defs[6], _ruin_defs[7], _bush_defs[2], _rock_defs[1]]
	var want := int(path_cells.size() * path_prop_density)
	var attempts := want * 12
	var placed := 0
	while placed < want and attempts > 0:
		attempts -= 1
		var p := path_cells[rng.randi() % path_cells.size()]
		var d := DIRS[rng.randi() % DIRS.size()]
		var cell := p + d
		if _in_bounds(cell) and (_cells[_idx(cell.x, cell.y)] == Cell.PATH or _cells[_idx(cell.x, cell.y)] == Cell.PLAZA):
			cell = p + d * 2
		if not _can_place_prop(cell):
			continue
		var def: Dictionary = pool[rng.randi() % pool.size()]
		_spawn_obstacle(def, cell)
		_mark_blocked(cell, Vector2i(1, 1))
		placed += 1


func _can_place_prop(cell: Vector2i) -> bool:
	if cell.x < 3 or cell.y < 3 or cell.x >= _grid_w - 3 or cell.y >= _grid_h - 3:
		return false
	var kind := _cells[_idx(cell.x, cell.y)]
	if kind != Cell.FOREST and kind != Cell.ROOM:
		return false
	if _in_special_zone(Rect2i(cell, Vector2i(1, 1))):
		return false
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			if _blocked[_idx(x, y)] == 1:
				return false
	return true


# ---- Tượng / bia mộ ở cuối mỗi nhánh cụt
func _place_branch_props() -> void:
	var pool: Array = [_ruin_defs[2], _ruin_defs[2], _ruin_defs[0], _ruin_defs[1], _ruin_defs[3]]
	for end in _branch_ends:
		if _blocked[_idx(end.x, end.y)] == 1:
			continue
		var def: Dictionary = pool[rng.randi() % pool.size()]
		_spawn_obstacle(def, end)
		_mark_blocked(end, Vector2i(1, 1))


# ---- Bốn cột đá ở góc quảng trường cổng Boss
func _place_portal_props() -> void:
	var pillar: Dictionary = _ruin_defs[3]
	for sx in [-3, 3]:
		for sy in [-3, 3]:
			var cell: Vector2i = _portal_cell + Vector2i(sx, sy)
			if _in_bounds(cell) and _blocked[_idx(cell.x, cell.y)] == 0:
				_spawn_obstacle(pillar, cell)
				_mark_blocked(cell, Vector2i(1, 1))


# ---- Cây rất thưa, mọc thành cụm theo nhiễu; hai hàng ngoài cùng của map là cây dày để làm biên
func _fill_forest() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.07
	for y in _grid_h:
		for x in _grid_w:
			var i := _idx(x, y)
			if _cells[i] != Cell.FOREST or _blocked[i] == 1:
				continue
			var edge := mini(mini(x, y), mini(_grid_w - 1 - x, _grid_h - 1 - y))
			var def: Dictionary
			if edge == 0:
				def = _tree_defs[rng.randi() % _tree_defs.size()]
			elif edge == 1:
				if rng.randf() >= 0.85:
					continue
				def = _tree_defs[rng.randi() % _tree_defs.size()] if rng.randf() < 0.7 else _bush_defs[rng.randi() % _bush_defs.size()]
			else:
				# Ngoài cụm gần như trống; trong cụm (nhiễu cao) mật độ tăng gấp vài lần.
				var clump := clampf((noise.get_noise_2d(x, y) - tree_clump_threshold) / 0.35, 0.0, 1.0)
				if rng.randf() >= tree_density * (0.4 + 2.6 * clump):
					continue
				def = _tree_defs[rng.randi() % _tree_defs.size()] if rng.randf() < 0.45 else _bush_defs[rng.randi() % _bush_defs.size()]
			_spawn_obstacle(def, Vector2i(x, y))
			_blocked[i] = 1


# ---- Cỏ trang trí (không va chạm), chỉ đặt trên ô phòng còn trống
func _scatter_decor() -> void:
	for y in _grid_h:
		for x in _grid_w:
			var i := _idx(x, y)
			if _cells[i] != Cell.ROOM or _blocked[i] == 1:
				continue
			if rng.randf() >= grass_decor_density:
				continue
			var def: Dictionary = _decor_defs[rng.randi() % _decor_defs.size()]
			var s := Sprite2D.new()
			s.texture = def["atlas"]
			s.scale = def["scale"]
			s.position = Vector2(
				(x + rng.randf_range(0.2, 0.8)) * tile_size,
				(y + rng.randf_range(0.2, 0.8)) * tile_size)
			_decor_root.add_child(s)


func _spawn_obstacle(def: Dictionary, cell: Vector2i) -> void:
	var fp: Vector2i = def["footprint"]
	var region: Rect2 = def["region"]
	var body := StaticBody2D.new()
	# Gốc của vật cản nằm ở GIỮA ĐÁY ô nó chiếm -> Y-Sort che khuất đúng.
	body.position = Vector2((cell.x + fp.x * 0.5) * tile_size, (cell.y + fp.y) * tile_size)

	var sprite := Sprite2D.new()
	sprite.texture = def["atlas"]
	sprite.scale = def["scale"]
	sprite.centered = false
	sprite.offset = Vector2(-region.size.x * 0.5, -region.size.y)
	body.add_child(sprite)

	var shape: RectangleShape2D = def["shape"]
	if shape != null:
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = Vector2(0, -shape.size.y * 0.5)
		body.add_child(col)

	_entities.add_child(body)


func _mark_blocked(cell: Vector2i, fp: Vector2i) -> void:
	for y in range(cell.y, cell.y + fp.y):
		for x in range(cell.x, cell.x + fp.x):
			if _in_bounds(Vector2i(x, y)):
				_blocked[_idx(x, y)] = 1


## Bốn bức tường vô hình bao quanh map (phòng khi Player lọt qua khe giữa các thân cây ở biên).
func _build_boundary() -> void:
	_boundary = StaticBody2D.new()
	_boundary.name = "Boundary"
	var w := _map_size.x
	var h := _map_size.y
	var thickness := 128.0
	for rect in [
			Rect2(-thickness, -thickness, w + thickness * 2.0, thickness),
			Rect2(-thickness, h, w + thickness * 2.0, thickness),
			Rect2(-thickness, 0.0, thickness, h),
			Rect2(w, 0.0, thickness, h)]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = rect.position + rect.size * 0.5
		_boundary.add_child(col)
	add_child(_boundary)


func _finalize_explore() -> void:
	_compute_reachability()
	unreachable_cells = 0
	for i in _cells.size():
		if _cells[i] != Cell.FOREST and _clear[i] == 1 and _reachable[i] == 0:
			unreachable_cells += 1
	_portal_local = _cell_center(_portal_cell)
	_compute_spawn_cells()
	# Cổng Boss ở giữa quảng trường; đặt trước Entities để vẽ trên nền nhưng dưới nhân vật.
	_portal = BossPortal.new()
	_portal.position = _portal_local
	_portal.setup(float(plaza_radius) * _cell * 0.9)
	add_child(_portal)
	move_child(_portal, _entities.get_index())
	var portal_reachable := _reachable[_idx(_portal_cell.x, _portal_cell.y)] == 1
	# Hợp lệ khi: điểm xuất phát đứng được, cổng Boss tới được, mọi phòng tới được, và chỉ có vài ô trống bị cô lập.
	var rooms_reachable := true
	for room in _rooms:
		var c := room.get_center()
		if _clear[_idx(c.x, c.y)] == 1 and _reachable[_idx(c.x, c.y)] == 0:
			rooms_reachable = false
	map_valid = _start_valid() and portal_reachable and rooms_reachable and unreachable_cells <= max_unreachable_cells


# ================================================================ Phòng Boss
func _build_arena() -> void:
	var rect_mode := theme != null and theme.arena_rect
	_grid_w = theme.arena_grid.x if rect_mode else arena_grid_size.x
	_grid_h = theme.arena_grid.y if rect_mode else arena_grid_size.y
	_cell = arena_cell_size
	_map_size = Vector2(_grid_w, _grid_h) * _cell
	_blocked.resize(_grid_w * _grid_h)
	var center_cell := Vector2(_grid_w, _grid_h) * 0.5
	var half_cells := theme.arena_half_cells if rect_mode else Vector2.ZERO
	for y in _grid_h:
		for x in _grid_w:
			var inside: bool
			if rect_mode:
				inside = absf(x + 0.5 - center_cell.x) <= half_cells.x and absf(y + 0.5 - center_cell.y) <= half_cells.y
			else:
				inside = Vector2(x + 0.5, y + 0.5).distance_to(center_cell) <= arena_radius_cells
			_blocked[y * _grid_w + x] = 0 if inside else 1
	# Vật cản trong đấu trường: theo bố cục của theme (nếu có), mặc định 4 cột đá.
	var pillar_cells: Array[Vector2] = []
	var pillar_rs: Array[float] = []
	if rect_mode:
		for entry in theme.arena_rect_pillars:
			pillar_cells.append(center_cell + Vector2(entry.x * half_cells.x, entry.y * half_cells.y))
			pillar_rs.append(entry.z)
	else:
		var layout: Array[Vector3] = []
		if theme != null and not theme.arena_pillars.is_empty():
			layout = theme.arena_pillars
		else:
			for k in 4:
				layout.append(Vector3(45.0 + 90.0 * k, 0.58, 1.8))
		for entry in layout:
			pillar_cells.append(center_cell + Vector2.from_angle(deg_to_rad(entry.x)) * arena_radius_cells * entry.y)
			pillar_rs.append(entry.z)
	for i in pillar_cells.size():
		var pillar_cell := pillar_cells[i]
		var pillar_r := pillar_rs[i]
		_arena_pillars.append(pillar_cell * _cell)
		_arena_pillar_radii.append(pillar_r)
		var reach := int(ceil(pillar_r)) + 1
		for y in range(int(pillar_cell.y) - reach, int(pillar_cell.y) + reach + 1):
			for x in range(int(pillar_cell.x) - reach, int(pillar_cell.x) + reach + 1):
				if x >= 0 and y >= 0 and x < _grid_w and y < _grid_h and Vector2(x + 0.5, y + 0.5).distance_to(pillar_cell) <= pillar_r:
					_blocked[y * _grid_w + x] = 1
	_arena_center = center_cell * _cell
	if rect_mode:
		_arena_half_px = half_cells * _cell
		_arena_radius_px = minf(half_cells.x, half_cells.y) * _cell
		@warning_ignore("integer_division")
		_start_cell = Vector2i(_grid_w / 2, int(center_cell.y + half_cells.y * 0.78))
	else:
		_arena_radius_px = arena_radius_cells * _cell
		@warning_ignore("integer_division")
		_start_cell = Vector2i(_grid_w / 2, int(center_cell.y + arena_radius_cells * 0.78))
	_bg_mode = BgMode.ARENA


func _finalize_grid() -> void:
	_build_arena_collision()
	_compute_reachability()
	_compute_spawn_cells()
	unreachable_cells = 0
	map_valid = _start_valid() and _reachable_count() > 100


## Gom các ô chặn liền nhau thành hình chữ nhật va chạm cho đấu trường.
func _build_arena_collision() -> void:
	var count := _grid_w * _grid_h
	# Chỉ giữ ô chặn nằm sát ô trống (trong WALL_MARGIN_CELLS) cho nhẹ; phần sâu trong tường Player không bao giờ tới.
	var near := PackedByteArray()
	near.resize(count)
	var tmp := PackedByteArray()
	tmp.resize(count)
	for y in _grid_h:  # dilate theo hàng
		for x in _grid_w:
			if _blocked[y * _grid_w + x] == 0:
				for dx in range(-WALL_MARGIN_CELLS, WALL_MARGIN_CELLS + 1):
					var nx := x + dx
					if nx >= 0 and nx < _grid_w:
						tmp[y * _grid_w + nx] = 1
	for y in _grid_h:  # rồi theo cột
		for x in _grid_w:
			if tmp[y * _grid_w + x] == 1:
				for dy in range(-WALL_MARGIN_CELLS, WALL_MARGIN_CELLS + 1):
					var ny := y + dy
					if ny >= 0 and ny < _grid_h:
						near[ny * _grid_w + x] = 1

	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = 1
	_walls.collision_mask = 0
	# Ghép các ô theo hàng, rồi nối dọc những đoạn trùng khít.
	var open_runs: Dictionary = {}  # Vector2i(x_bắt_đầu, x_kết_thúc) -> hàng bắt đầu
	for y in range(_grid_h + 1):
		var runs: Dictionary = {}
		if y < _grid_h:
			var x := 0
			while x < _grid_w:
				if _is_wall_cell(x, y, near):
					var x0 := x
					while x < _grid_w and _is_wall_cell(x, y, near):
						x += 1
					runs[Vector2i(x0, x)] = true
				else:
					x += 1
		for key: Vector2i in open_runs.keys():
			if not runs.has(key):
				_add_wall_rect(key.x, key.y, int(open_runs[key]), y)
				open_runs.erase(key)
		for key: Vector2i in runs.keys():
			if not open_runs.has(key):
				open_runs[key] = y
	add_child(_walls)


func _is_wall_cell(x: int, y: int, near: PackedByteArray) -> bool:
	var i := y * _grid_w + x
	return _blocked[i] == 1 and near[i] == 1


func _add_wall_rect(x0: int, x1: int, y0: int, y1: int) -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, y1 - y0) * _cell
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = Vector2(x0 + x1, y0 + y1) * 0.5 * _cell
	_walls.add_child(shape)
	_wall_rect_count += 1


# ================================================================ Dùng chung: vùng tới được, ô spawn, hướng đi
## _clear = ô và cả 8 ô quanh nó trống (đủ chỗ cho thân Player/Enemy). _reachable = loang 4 hướng từ ô xuất phát qua các ô _clear.
func _compute_reachability() -> void:
	var count := _grid_w * _grid_h
	_clear.resize(count)
	_clear.fill(0)
	_reachable.resize(count)
	_reachable.fill(0)
	for y in range(1, _grid_h - 1):
		for x in range(1, _grid_w - 1):
			var ok := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if _blocked[(y + dy) * _grid_w + (x + dx)] == 1:
						ok = false
			if ok:
				_clear[y * _grid_w + x] = 1
	# Nếu ô xuất phát không đứng được thì dời tới ô đứng được gần nhất.
	if not _start_valid():
		var best := Vector2i(-1, -1)
		var best_d := INF
		for y in range(1, _grid_h - 1):
			for x in range(1, _grid_w - 1):
				if _clear[y * _grid_w + x] == 1:
					var d := Vector2(x, y).distance_squared_to(Vector2(_start_cell))
					if d < best_d:
						best_d = d
						best = Vector2i(x, y)
		if best.x < 0:
			return
		_start_cell = best
	var queue := PackedInt32Array()
	queue.append(_start_cell.y * _grid_w + _start_cell.x)
	_reachable[queue[0]] = 1
	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		var cx := idx % _grid_w
		@warning_ignore("integer_division")
		var cy := idx / _grid_w
		for dir in DIRS:
			var nx: int = cx + dir.x
			var ny: int = cy + dir.y
			if nx < 0 or ny < 0 or nx >= _grid_w or ny >= _grid_h:
				continue
			var ni := ny * _grid_w + nx
			if _clear[ni] == 1 and _reachable[ni] == 0:
				_reachable[ni] = 1
				queue.append(ni)


func _compute_spawn_cells() -> void:
	_spawn_cells.clear()
	for y in _grid_h:
		for x in _grid_w:
			if _reachable[y * _grid_w + x] == 0:
				continue
			var c := Vector2i(x, y)
			if _portal != null and _cell_center(c).distance_to(_portal_local) < portal_no_spawn_radius:
				continue
			_spawn_cells.append(c)


func _start_valid() -> bool:
	return _start_cell.x >= 0 and _start_cell.y >= 0 and _start_cell.x < _grid_w and _start_cell.y < _grid_h \
			and _clear.size() > 0 and _clear[_start_cell.y * _grid_w + _start_cell.x] == 1


func _reachable_count() -> int:
	var total := 0
	for v in _reachable:
		total += v
	return total


## Loang theo chiều rộng từ ô của Player qua các ô "clear" (4 hướng), ghi số bước vào _flow_dist.
func _rebuild_flow(target_cell: Vector2i) -> void:
	var count := _grid_w * _grid_h
	if _flow_dist.size() != count:
		_flow_dist.resize(count)
	_flow_dist.fill(-1)
	var start := _nearest_clear_cell(target_cell, 3)
	if start.x < 0:
		_flow_cell = Vector2i(-1, -1)
		return
	_flow_cell = target_cell
	var queue := PackedInt32Array()
	queue.append(start.y * _grid_w + start.x)
	_flow_dist[queue[0]] = 0
	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		var d := _flow_dist[idx]
		if d >= FLOW_RADIUS_STEPS:
			continue
		var cx := idx % _grid_w
		@warning_ignore("integer_division")
		var cy := idx / _grid_w
		if cx + 1 < _grid_w and _clear[idx + 1] == 1 and _flow_dist[idx + 1] < 0:
			_flow_dist[idx + 1] = d + 1
			queue.append(idx + 1)
		if cx > 0 and _clear[idx - 1] == 1 and _flow_dist[idx - 1] < 0:
			_flow_dist[idx - 1] = d + 1
			queue.append(idx - 1)
		if cy + 1 < _grid_h and _clear[idx + _grid_w] == 1 and _flow_dist[idx + _grid_w] < 0:
			_flow_dist[idx + _grid_w] = d + 1
			queue.append(idx + _grid_w)
		if cy > 0 and _clear[idx - _grid_w] == 1 and _flow_dist[idx - _grid_w] < 0:
			_flow_dist[idx - _grid_w] = d + 1
			queue.append(idx - _grid_w)


func _flow_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= _grid_w or y >= _grid_h:
		return -1
	return _flow_dist[y * _grid_w + x]


func _nearest_clear_cell(cell: Vector2i, max_radius: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-max_radius, max_radius + 1):
		for dx in range(-max_radius, max_radius + 1):
			var x := cell.x + dx
			var y := cell.y + dy
			if x < 0 or y < 0 or x >= _grid_w or y >= _grid_h:
				continue
			if _clear[y * _grid_w + x] == 1 and float(dx * dx + dy * dy) < best_d:
				best_d = float(dx * dx + dy * dy)
				best = Vector2i(x, y)
	return best


# ================================================================ Tiện ích
func _idx(x: int, y: int) -> int:
	return y * _grid_w + x


func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < _grid_w and p.y < _grid_h


func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x + 0.5, c.y + 0.5) * _cell


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos)
	return Vector2i(floori(local.x / _cell), floori(local.y / _cell))


# ================================================================ Vẽ
## Hình tạm cho đấu trường Boss (Phase 7 sẽ thay bằng hình thật nếu có asset).
func _on_bg_draw() -> void:
	if _bg_mode != BgMode.ARENA:
		return
	var c := _arena_center
	var r := _arena_radius_px
	if theme != null and theme.path_texture != null and not theme.arena_tiles.is_empty():
		_draw_themed_arena(c, r)
		return
	_bg.draw_rect(Rect2(Vector2.ZERO, _map_size), Color(0.03, 0.02, 0.05))
	_bg.draw_circle(c, r, Color(0.15, 0.12, 0.19))
	_bg.draw_circle(c, r * 0.96, Color(0.19, 0.16, 0.25))
	for k in [0.25, 0.5, 0.75]:
		_bg.draw_arc(c, r * k, 0.0, TAU, 96, Color(0.32, 0.26, 0.42, 0.7), 2.0)
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		_bg.draw_line(c + dir * r * 0.12, c + dir * r * 0.94, Color(0.32, 0.26, 0.42, 0.55), 2.0)
	_bg.draw_arc(c, r * 0.12, 0.0, TAU, 32, Color(0.75, 0.55, 1.0, 0.9), 3.0)
	_bg.draw_arc(c, r, 0.0, TAU, 128, Color(0.7, 0.55, 0.9, 0.95), 5.0)
	for p in _arena_pillars:
		_bg.draw_circle(p, _cell * 1.9, Color(0.1, 0.08, 0.13))
		_bg.draw_circle(p, _cell * 1.7, Color(0.33, 0.29, 0.4))
		_bg.draw_circle(p + Vector2(-_cell * 0.3, -_cell * 0.3), _cell * 0.9, Color(0.45, 0.4, 0.52))


## Đấu trường dựng từ ô ảnh của theme (gạch), cột đá vẽ theo bảng màu của theme.
func _draw_themed_arena(c: Vector2, r: float) -> void:
	_bg.draw_rect(Rect2(Vector2.ZERO, _map_size), theme.arena_bg)
	if theme.arena_rect:
		_draw_rect_arena(c)
		return
	var tpx := float(theme.tile_px)
	var center_cell := Vector2(_grid_w, _grid_h) * 0.5
	for y in _grid_h:
		for x in _grid_w:
			if Vector2(x + 0.5, y + 0.5).distance_to(center_cell) > arena_radius_cells + 0.5:
				continue
			var tile: Vector2i = theme.arena_tiles[(x * 7 + y * 13 + (x * y) % 5) % theme.arena_tiles.size()]
			_bg.draw_texture_rect_region(theme.path_texture, Rect2(Vector2(x, y) * _cell, Vector2(_cell, _cell)), Rect2(Vector2(tile) * tpx, Vector2(tpx, tpx)), theme.arena_tint)
	for k in [0.25, 0.5, 0.75]:
		_bg.draw_arc(c, r * k, 0.0, TAU, 96, theme.arena_ring, 2.0)
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		_bg.draw_line(c + dir * r * 0.12, c + dir * r * 0.94, Color(theme.arena_ring, theme.arena_ring.a * 0.8), 2.0)
	_bg.draw_arc(c, r * 0.12, 0.0, TAU, 32, theme.arena_rune, 3.0)
	_bg.draw_arc(c, r, 0.0, TAU, 128, theme.arena_rim, 5.0)
	for i in _arena_pillars.size():
		var p := _arena_pillars[i]
		var pr: float = _arena_pillar_radii[i] if i < _arena_pillar_radii.size() else 1.8
		_bg.draw_circle(p, _cell * (pr + 0.1), theme.pillar_dark)
		_bg.draw_circle(p, _cell * (pr - 0.1), theme.pillar_mid)
		_bg.draw_circle(p + Vector2(-_cell * 0.3, -_cell * 0.3) * (pr / 1.8), _cell * pr * 0.5, theme.pillar_light)
		if not theme.pillar_sprites.is_empty():
			var def: Dictionary = theme.pillar_sprites[i % theme.pillar_sprites.size()]
			var region: Rect2 = def["region"]
			var height := _cell * pr * 3.0  # cao hơn đường kính một chút cho giống khối đá thật
			var size := Vector2(region.size.x / region.size.y * height, height)
			_bg.draw_texture_rect(def["atlas"], Rect2(p + Vector2(-size.x * 0.5, -size.y + _cell * pr * 0.9), size), false)


func _on_overlay_draw() -> void:
	if not debug_draw or _grid_w == 0:
		return
	for room in _rooms:
		_overlay.draw_rect(Rect2(Vector2(room.position) * _cell, Vector2(room.size) * _cell), Color(0.2, 0.5, 1.0, 0.18), true)
	for y in _grid_h:
		for x in _grid_w:
			var i := _idx(x, y)
			var rect := Rect2(Vector2(x, y) * _cell, Vector2(_cell, _cell))
			if current_layout == Layout.BOSS_ARENA and _blocked[i] == 1:
				_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.3))
			elif i < _cells.size() and _cells[i] == Cell.PATH:
				_overlay.draw_rect(rect, Color(1.0, 0.9, 0.2, 0.18))
			elif i < _cells.size() and _cells[i] == Cell.PLAZA:
				_overlay.draw_rect(rect, Color(0.8, 0.3, 1.0, 0.3))
			if _clear[i] == 1 and _reachable[i] == 0 and (i >= _cells.size() or _cells[i] != Cell.FOREST):
				_overlay.draw_rect(rect, Color(1.0, 0.0, 0.0, 0.6))  # đi được nhưng KHÔNG tới được = lỗi
	for c in _spawn_cells:  # chấm xanh lơ nhỏ = ô Enemy có thể xuất hiện
		_overlay.draw_circle(_cell_center(c), 2.5, Color(0.2, 0.9, 1.0, 0.7))
	_overlay.draw_circle(_cell_center(_start_cell), 12.0, Color(0.1, 1.0, 0.2, 0.9))


## Đấu trường chữ nhật (level 4): sàn gạch, viền tường đá (khối tường 64 px), vòng rune giữa sàn, cột đá để nấp.
func _draw_rect_arena(c: Vector2) -> void:
	var tpx := float(theme.tile_px)
	var half := _arena_half_px
	var rect := Rect2(c - half, half * 2.0)
	var cols := int(round(half.x * 2.0 / _cell))
	var rows := int(round(half.y * 2.0 / _cell))
	for iy in rows:
		for ix in cols:
			var tile: Vector2i = theme.arena_tiles[(ix * 7 + iy * 13 + (ix * iy) % 5) % theme.arena_tiles.size()]
			_bg.draw_texture_rect_region(theme.path_texture, Rect2(rect.position + Vector2(ix, iy) * _cell, Vector2(_cell, _cell)), Rect2(Vector2(tile) * tpx, Vector2(tpx, tpx)), theme.arena_tint)
	# Hoa văn: vòng rune ở giữa và các đường chéo mờ.
	for k in [0.18, 0.34]:
		_bg.draw_arc(c, half.y * k * 1.6, 0.0, TAU, 64, theme.arena_ring, 2.0)
	_bg.draw_arc(c, half.y * 0.18 * 1.6 * 0.5, 0.0, TAU, 32, theme.arena_rune, 3.0)
	_bg.draw_line(rect.position, rect.end, Color(theme.arena_ring, theme.arena_ring.a * 0.5), 2.0)
	_bg.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color(theme.arena_ring, theme.arena_ring.a * 0.5), 2.0)
	_draw_arena_walls(rect)
	_bg.draw_rect(rect, theme.arena_rim, false, 3.0)
	for i in _arena_pillars.size():
		var p := _arena_pillars[i]
		var pr: float = _arena_pillar_radii[i] if i < _arena_pillar_radii.size() else 1.8
		_bg.draw_circle(p, _cell * (pr + 0.1), theme.pillar_dark)
		_bg.draw_circle(p, _cell * (pr - 0.1), theme.pillar_mid)
		_bg.draw_circle(p + Vector2(-_cell * 0.3, -_cell * 0.3) * (pr / 1.8), _cell * pr * 0.5, theme.pillar_light)
		if not theme.pillar_sprites.is_empty():
			var def: Dictionary = theme.pillar_sprites[i % theme.pillar_sprites.size()]
			var region: Rect2 = def["region"]
			var height := _cell * pr * 3.0
			var size := Vector2(region.size.x / region.size.y * height, height)
			_bg.draw_texture_rect(def["atlas"], Rect2(p + Vector2(-size.x * 0.5, -size.y + _cell * pr * 0.9), size), false)


## Viền tường đá quanh sàn chữ nhật bằng các khối tường 64x64 (TX Tileset Wall): trên dày 64 px (đỉnh + thân), hai bên và dưới dày 48 px.
func _draw_arena_walls(rect: Rect2) -> void:
	var tex := theme.wall_texture
	if tex == null:
		return
	var block_a := Vector2(32.0, 288.0)  # góc trái trên của hai khối tường trong TX Tileset Wall.png
	var block_b := Vector2(128.0, 288.0)
	var tint := Color(0.78, 0.8, 0.95)
	var top_y := rect.position.y - 64.0
	var x := rect.position.x - 48.0
	var i := 0
	while x < rect.end.x + 48.0:
		var b := block_a if i % 2 == 0 else block_b
		var w := minf(64.0, rect.end.x + 48.0 - x)
		_bg.draw_texture_rect_region(tex, Rect2(x, top_y, w, 64.0), Rect2(b, Vector2(w, 64.0)), tint)
		# Dưới: nửa trên khối (đỉnh + thân) quay vào trong phòng.
		_bg.draw_texture_rect_region(tex, Rect2(x, rect.end.y, w, 48.0), Rect2(b, Vector2(w, 48.0)), tint.darkened(0.15))
		x += 64.0
		i += 1
	var y := rect.position.y
	while y < rect.end.y:
		var h := minf(44.0, rect.end.y - y)
		var src := Rect2(block_a + Vector2(12.0, 16.0), Vector2(48.0, h))
		_bg.draw_texture_rect_region(tex, Rect2(rect.position.x - 48.0, y, 48.0, h), src, tint.darkened(0.1))
		_bg.draw_texture_rect_region(tex, Rect2(rect.end.x, y, 48.0, h), src, tint.darkened(0.1))
		y += 44.0
