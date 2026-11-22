class_name EnemySpawner
extends Node
## Tự động sinh Enemy bằng Timer, giữ số Enemy đang sống tiến tới số Enemy MỤC TIÊU nhưng không vượt giới hạn.
## Gắn vào node "EnemySpawner" (kiểu Node) là con của Main.
## Số Enemy đang sống được đếm trực tiếp từ nhóm "enemies" (Enemy rời nhóm ngay khi chết) nên luôn chính xác.

signal enemy_spawned(enemy: Enemy)

## Tỉ lệ và giới hạn số lượng từng loại (LevelConfig ghi đè khi vào màn). Cùng thứ tự với enemy_scenes.
var enemy_weights: Array[float] = []
var enemy_caps: Array[int] = []
## > 0 = sinh theo đợt (xem LevelConfig.spawn_batch_min/max).
var spawn_batch_min: int = 0
var spawn_batch_max: int = 0

@export_group("Enemy")
## Các scene Enemy có thể xuất hiện (kéo Slime, Wolf, Bat, Skeleton, Mage vào). Hiện chọn ngẫu nhiên đều nhau.
@export var enemy_scenes: Array[PackedScene] = []

@export_group("Số lượng")
## Số Enemy mục tiêu khi người chơi chưa có Spell nào.
@export var base_enemy_count: int = 3
## Giới hạn cứng: số Enemy đang sống không bao giờ vượt quá con số này.
@export var max_enemies: int = 30
## Số Enemy xuất hiện ngay khi lượt chơi bắt đầu.
@export var initial_spawn_count: int = 3

@export_group("Nhịp spawn")
## Thời gian giữa 2 lần kiểm tra và bổ sung Enemy khi CHƯA có Spell (giây). Có Spell thì ngắn hơn.
@export_range(0.2, 30.0, 0.1) var spawn_interval: float = 2.0
## Mỗi lần kiểm tra, sinh tối đa bấy nhiêu Enemy (nếu còn thiếu so với mục tiêu).
@export var spawn_per_tick: int = 1

@export_group("Độ khó theo Spell")
## Mỗi Spell đã thu thập cộng thêm bấy nhiêu Enemy mục tiêu (số lẻ được làm tròn).
@export var enemies_per_spell: float = 1.5
## Ngưỡng độ khó: khi số Spell >= ngưỡng thì cộng thêm số Enemy ở mảng bên dưới (cộng dồn).
## Hai mảng phải cùng độ dài. Ví dụ [2, 4] và [2, 3]: từ 2 Spell +2 Enemy, từ 4 Spell +3 Enemy nữa.
@export var threshold_spell_counts: Array[int] = [2, 4]
@export var threshold_bonus_enemies: Array[int] = [2, 3]
## Mỗi Spell nhân nhịp spawn với hệ số này (0.9 = nhanh hơn 10% mỗi Spell).
@export_range(0.5, 1.0, 0.01) var interval_multiplier_per_spell: float = 0.9
## Nhịp spawn không bao giờ nhanh hơn mức này (giây).
@export var min_spawn_interval: float = 0.6
## Số Enemy sinh NGAY khi nhặt Spell mới (vẫn không vượt mục tiêu và giới hạn).
@export var burst_on_spell: int = 2
## Chỉ tính tối đa bấy nhiêu Spell vào độ khó (chặn tăng quá nhanh).
@export var max_effective_spells: int = 10

@export_group("Vị trí")
## Enemy xuất hiện cách Player trong khoảng này (pixel). Màn hình rộng 1152 nên 350 gần mép màn hình.
@export var min_spawn_distance: float = 350.0
@export var max_spawn_distance: float = 900.0
## Không sinh Enemy mới trong bán kính này quanh Enemy khác (tránh chồng lên nhau).
@export var min_gap_between_enemies: float = 48.0
## Số lần thử tìm vị trí cho mỗi Enemy trước khi bỏ qua lượt đó.
@export var max_position_attempts: int = 12

var _world: MapGenerator
var _player: Node2D
var _timer: Timer
var _running: bool = false


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)  # Timer tự dừng khi game tạm dừng (get_tree().paused)
	GameManager.run_ended.connect(_on_run_ended)
	SpellSystem.spell_collected.connect(_on_spell_collected)
	SpellSystem.collection_reset.connect(_on_collection_reset)


# ---------------------------------------------------------------- Điều khiển
## Áp cấu hình độ khó của một Level (loại Enemy, số lượng mục tiêu, ngưỡng theo số Spell). Gọi trước start_run().
func apply_level(level: LevelConfig) -> void:
	if level == null:
		return
	if not level.enemy_scenes.is_empty():
		enemy_scenes = level.enemy_scenes.duplicate()
	enemy_weights = level.enemy_weights.duplicate()
	enemy_caps = level.enemy_caps.duplicate()
	base_enemy_count = level.base_enemy_count
	enemies_per_spell = level.enemies_per_spell
	threshold_spell_counts = level.threshold_spell_counts.duplicate()
	threshold_bonus_enemies = level.threshold_bonus_enemies.duplicate()
	max_enemies = level.max_enemies
	spawn_interval = level.spawn_interval
	initial_spawn_count = level.initial_spawn_count
	spawn_batch_min = level.spawn_batch_min
	spawn_batch_max = maxi(level.spawn_batch_max, level.spawn_batch_min)


## Main gọi khi MAP ĐÃ SẴN SÀNG và Player đã được đặt. Bắt đầu một lượt spawn mới.
func start_run(p_world: MapGenerator, p_player: Node2D) -> void:
	_world = p_world
	_player = p_player
	_clear_enemies()
	_running = true
	if spawn_batch_min > 0:
		_spawn_wave()
	else:
		var initial := mini(initial_spawn_count, get_target_enemy_count())
		for i in initial:
			_spawn_one()
	_timer.start(spawn_interval)


## Dừng spawn (Player chết, hết lượt...). Enemy đang sống không bị xóa.
func stop() -> void:
	_running = false
	_timer.stop()


# ---------------------------------------------------------------- Số lượng
## Số Enemy mục tiêu hiện tại, đã bị chặn bởi max_enemies.
func get_target_enemy_count() -> int:
	return clampi(compute_target_enemy_count(), 0, max_enemies)


## Công thức độ khó:
##   mục tiêu = base + số_Spell * enemies_per_spell + tổng bonus của các ngưỡng đã đạt
## (kết quả sau đó bị chặn bởi max_enemies). Chỉ phụ thuộc số Spell ĐÃ THU THẬP,
## nên đổi hay tháo trang bị không ảnh hưởng.
func compute_target_enemy_count() -> int:
	var spells := get_effective_spell_count()
	return base_enemy_count + roundi(spells * enemies_per_spell) + _threshold_bonus(spells)


## Nhịp spawn hiện tại (giây): nhanh dần theo số Spell nhưng không dưới min_spawn_interval.
func get_spawn_interval() -> float:
	var spells := get_effective_spell_count()
	return maxf(min_spawn_interval, spawn_interval * pow(interval_multiplier_per_spell, spells))


func get_effective_spell_count() -> int:
	return mini(SpellSystem.get_collected_count(), max_effective_spells)


func _threshold_bonus(spells: int) -> int:
	var total := 0
	for i in mini(threshold_spell_counts.size(), threshold_bonus_enemies.size()):
		if spells >= threshold_spell_counts[i]:
			total += threshold_bonus_enemies[i]
	return total


func _on_spell_collected(_spell: SpellData, _total: int) -> void:
	# Signal này phát ra từ trong body_entered của SpellPickup (Area2D), tức là ngay giữa lúc Godot đang xử lý
	# va chạm. Lúc đó KHÔNG được thêm/sửa vật thể vật lý (Enemy), nên dời việc sinh Enemy sang cuối frame.
	_refresh_difficulty.call_deferred(true)


func _on_collection_reset() -> void:
	_refresh_difficulty(false)


## Gọi khi số Spell đổi: áp nhịp spawn mới, in log, và (tuỳ chọn) sinh vài Enemy ngay.
func _refresh_difficulty(allow_burst: bool) -> void:
	print("[Spawner] Spell=%d -> mục tiêu %d Enemy | nhịp spawn %.2fs" % [get_effective_spell_count(), get_target_enemy_count(), get_spawn_interval()])
	if not _running:
		return
	if spawn_batch_min > 0:
		return  # kiểu đợt: nhịp và số lượng không đổi theo Spell
	_timer.start(get_spawn_interval())
	if allow_burst:
		var deficit := get_target_enemy_count() - get_enemy_count()
		for i in mini(deficit, burst_on_spell):
			if not _spawn_one():
				break


func get_enemy_count() -> int:
	# Đếm trực tiếp, không tạo mảng mới (HUD gọi hàm này nhiều lần mỗi giây).
	return get_tree().get_node_count_in_group("enemies")


## Dùng cho kiểm thử hiệu năng: sinh NGAY tối đa count Enemy (vẫn tôn trọng max_enemies và vị trí hợp lệ).
## Trả về số Enemy thực sự được sinh.
func spawn_now(count: int) -> int:
	var spawned := 0
	for i in count:
		if _spawn_one():
			spawned += 1
	return spawned


# ---------------------------------------------------------------- Nội bộ
func _on_timer_timeout() -> void:
	if not _running:
		return
	if not is_instance_valid(_world) or not is_instance_valid(_player):
		stop()
		return
	if spawn_batch_min > 0:
		if get_enemy_count() <= max_enemies - spawn_batch_max:
			_spawn_wave()
		return
	var deficit := get_target_enemy_count() - get_enemy_count()
	for i in mini(deficit, spawn_per_tick):
		if not _spawn_one():
			break  # không tìm được chỗ, thử lại ở lượt sau
	_timer.wait_time = get_spawn_interval()


## Sinh một đợt spawn_batch_min..max Enemy (không vượt max_enemies); bỏ cuộc sau 4 lần không tìm được chỗ.
func _spawn_wave() -> void:
	var count := randi_range(spawn_batch_min, spawn_batch_max)
	count = mini(count, max_enemies - get_enemy_count())
	var failures := 0
	var spawned := 0
	while spawned < count and failures < 4:
		if _spawn_one():
			spawned += 1
		else:
			failures += 1
	print("[Spawner] Đợt mới: %d / %d Enemy (đang sống %d / %d)" % [spawned, count, get_enemy_count(), max_enemies])


func _on_run_ended(_reason: StringName) -> void:
	stop()


func _spawn_one() -> bool:
	if enemy_scenes.is_empty() or get_enemy_count() >= max_enemies:
		return false
	var pos := _find_spawn_position()
	if pos == MapGenerator.NO_SPAWN:
		return false
	var scene := _pick_scene()
	if scene == null:
		return false  # mọi loại đều đã đạt giới hạn
	var enemy := scene.instantiate() as Enemy
	if enemy == null:
		push_error("EnemySpawner: scene '%s' chưa gắn script Enemy.gd." % scene.resource_path)
		return false
	_world.get_entities_root().add_child(enemy)
	enemy.global_position = pos
	enemy_spawned.emit(enemy)
	return true


## Chọn loại Enemy theo tỉ lệ (enemy_weights), bỏ qua loại đã đủ số lượng tối đa (enemy_caps). null nếu không còn loại nào.
func _pick_scene() -> PackedScene:
	var alive: Dictionary = {}  # đường dẫn scene -> số con đang sống (chỉ đếm khi có giới hạn)
	var has_caps := false
	for cap in enemy_caps:
		if cap >= 0:
			has_caps = true
	if has_caps:
		for e in get_tree().get_nodes_in_group("enemies"):
			var path: String = (e as Node).scene_file_path
			alive[path] = int(alive.get(path, 0)) + 1
	var total := 0.0
	var weights: Array[float] = []
	for i in enemy_scenes.size():
		var w := enemy_weights[i] if i < enemy_weights.size() else 1.0
		var cap := enemy_caps[i] if i < enemy_caps.size() else -1
		if cap >= 0 and int(alive.get(enemy_scenes[i].resource_path, 0)) >= cap:
			w = 0.0
		weights.append(maxf(w, 0.0))
		total += weights[i]
	if total <= 0.0:
		return null
	var roll := randf() * total
	for i in enemy_scenes.size():
		roll -= weights[i]
		if roll <= 0.0 and weights[i] > 0.0:
			return enemy_scenes[i]
	return enemy_scenes[enemy_scenes.size() - 1]


## Vị trí hợp lệ (do MapGenerator đảm bảo) và không sát Enemy khác.
func _find_spawn_position() -> Vector2:
	var gap_sq := min_gap_between_enemies * min_gap_between_enemies
	var enemies := get_tree().get_nodes_in_group("enemies")
	for attempt in max_position_attempts:
		var pos := _world.get_spawn_position(_player.global_position, min_spawn_distance, max_spawn_distance)
		if pos == MapGenerator.NO_SPAWN:
			return MapGenerator.NO_SPAWN
		var crowded := false
		for e in enemies:
			if (e as Node2D).global_position.distance_squared_to(pos) < gap_sq:
				crowded = true
				break
		if not crowded:
			return pos
	return MapGenerator.NO_SPAWN


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		# Rời nhóm NGAY: queue_free chỉ xóa node cuối frame, nếu không số đếm sẽ còn tính Enemy cũ.
		e.remove_from_group("enemies")
		e.queue_free()
