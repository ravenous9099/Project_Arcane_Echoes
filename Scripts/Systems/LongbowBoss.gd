class_name LongbowBoss
extends Boss
## Boss level 3 "Xạ thủ cung dài". KẾ THỪA Boss.gd (2 giai đoạn, nối đòn, bộ não học hành vi người chơi...), chỉ thay bộ đòn:
## toàn đòn TẦM XA, sát thương vừa phải nhưng gây hiệu ứng bất lợi (choáng / trói chân) lên Player.
##   FAN     : loạt tên băng tỏa quạt (trói chân)            [kế thừa Boss, fan_spell]
##   RING    : vòng tên băng (trói chân)                      [kế thừa Boss, ring_spell]
##   METEORS : mưa mũi tên rơi xuống quanh Player (trói chân) [kế thừa Boss, meteor_spell]
##   SLAM    : "Bùng băng" khi Player áp sát: đẩy lùi + choáng [kế thừa Boss, slam_spell]
##   SNIPE   : một mũi tên rất nhanh, ngắm đón đầu, báo trước bằng đường thẳng dài (choáng)
##   TRAPS   : vài bẫy băng nổ sau vòng cảnh báo quanh chỗ Player sẽ đứng (trói chân lâu)
##   BARRAGE : bắn liên tiếp, mỗi phát ngắm lại theo Player (trói chân ngắn)
## Tên (SNIPE, FAN, RING, BARRAGE) bị cột đá/băng trong phòng Boss chắn lại, nên Player có thể NÚP; Boss thấy mình bị che thì dồn
## sang đòn vùng (TRAPS, METEORS) ép Player rời chỗ nấp. Cứ mỗi minion_interval giây (mặc định 7) triệu hồi 1 CamoArcher.
## Không dùng CHARGE (Boss giữ khoảng cách xa và lùi khi bị áp sát).

signal minion_spawned(minion: Node)

const SNIPE: int = 8
const TRAPS: int = 9
const BARRAGE: int = 10

const LB_TIMING: Dictionary = {
	SNIPE: {"tele": 1.0, "lock": 0.4, "active": 0.55, "recover": 0.75, "gap": 0.4},
	TRAPS: {"tele": 0.55, "lock": 0.0, "active": 0.4, "recover": 0.8, "gap": 0.45},
	BARRAGE: {"tele": 0.65, "lock": 0.2, "active": 1.0, "recover": 0.7, "gap": 0.4},
}
const LB_FOLLOWUPS: Dictionary = {
	Pattern.SLAM: [BARRAGE, SNIPE],
	Pattern.FAN: [SNIPE, TRAPS],
	Pattern.METEORS: [SNIPE, BARRAGE],
	Pattern.RING: [SNIPE, TRAPS],
	SNIPE: [TRAPS, BARRAGE, Pattern.FAN],
	TRAPS: [SNIPE, BARRAGE],
	BARRAGE: [TRAPS, Pattern.FAN],
}

@export_group("Xạ thủ cung dài - đòn đánh")
@export var snipe_spell: SpellData
@export var barrage_spell: SpellData
@export var trap_spell: SpellData
## Số phát của BARRAGE (giai đoạn 2 cộng thêm 2) và giãn cách giữa các phát (giây).
@export var barrage_shots: int = 5
@export var barrage_interval: float = 0.15
## Số bẫy của TRAPS (giai đoạn 2 cộng thêm 2).
@export var trap_count: int = 3
## Khi Player áp sát, Boss lùi nhanh hơn bấy nhiêu lần so với bình thường.
@export var retreat_boost: float = 1.7

@export_group("Xạ thủ cung dài - triệu hồi")
@export var minion_scene: PackedScene
@export var minion_interval: float = 7.0
@export var minions_per_wave: int = 1
@export var max_minions: int = 4

var _barrage_done: int = 0
var _snipe_second_done: bool = false
var _minion_timer: float = 0.0
var _minions: Array[Node] = []


# ---------------------------------------------------------------- Dữ liệu đòn
func _build_frames() -> SpriteFrames:
	var sheets := {"idle": "Idle", "move": move_animation, "hit": "TakeDamage", "die": "Die",
			"attack": "QuickShot", "cast": "CastSpell", "charge": "AttackRun", "special": "Special1"}
	var loops := {"idle": true, "move": true, "hit": false, "die": false,
			"attack": false, "cast": false, "charge": false, "special": false}
	return CharacterFrames.build(character_folder, sheets, loops, frame_size, anim_fps)


func _get_timing(pattern: int) -> Dictionary:
	if LB_TIMING.has(pattern):
		return LB_TIMING[pattern]
	return super._get_timing(pattern)


func _get_followups(pattern: int) -> Array:
	return LB_FOLLOWUPS.get(pattern, [])


func _pattern_allowed(pattern: int, dist: float) -> bool:
	match pattern:
		Pattern.CHARGE:
			return false
		SNIPE:
			return snipe_spell != null and dist > 180.0 and _los_clear
		BARRAGE:
			return barrage_spell != null and dist > 150.0 and _los_clear
		TRAPS:
			return trap_spell != null
		Pattern.FAN, Pattern.RING:
			return _los_clear  # bị cột che thì tên vô ích
	return super._pattern_allowed(pattern, dist)


## Bộ đòn tầm xa. Player nấp sau cột (không có đường nhìn) thì chỉ còn đòn vùng để ép họ ra.
func _base_weights(dist: float) -> Dictionary:
	var weights: Dictionary = {}
	if slam_spell != null and dist < slam_spell.area_radius + 25.0:
		weights[Pattern.SLAM] = 5.0  # bị áp sát: đẩy ra
	if not _los_clear:
		weights[TRAPS] = 4.0
		weights[Pattern.METEORS] = 3.5
		return weights
	weights[Pattern.FAN] = 2.5
	weights[Pattern.METEORS] = 2.5 if _phase >= 2 else 2.0
	if trap_spell != null:
		weights[TRAPS] = 2.5
	if snipe_spell != null and dist > 180.0:
		weights[SNIPE] = 3.0
	if barrage_spell != null and dist > 150.0:
		weights[BARRAGE] = 3.0
	if _phase >= 2:
		weights[Pattern.RING] = 2.5
	return weights


# ---------------------------------------------------------------- Di chuyển
func _state_chase() -> void:
	if target != null and is_instance_valid(target):
		_update_line_of_sight(get_physics_process_delta_time())
	super._state_chase()
	# Giữ khoảng cách như cung thủ: bị áp sát thì lùi nhanh.
	if target != null and is_instance_valid(target) and global_position.distance_to(target.global_position) < preferred_distance - 60.0:
		_desired_velocity *= retreat_boost


# ---------------------------------------------------------------- Ngắm và ra đòn
func _update_attack_aim() -> void:
	super._update_attack_aim()
	if target == null or not is_instance_valid(target):
		return
	var speed := 0.0
	match _pattern:
		SNIPE:
			speed = snipe_spell.projectile_speed if snipe_spell != null else 0.0
		BARRAGE:
			speed = barrage_spell.projectile_speed if barrage_spell != null else 0.0
	if speed <= 0.0:
		return
	var dist := global_position.distance_to(target.global_position)
	var predicted := brain.predict_position(target.global_position, _target_velocity(), clampf(dist / speed, 0.0, 0.8))
	var to_predicted := predicted - global_position
	if to_predicted.length_squared() > 1.0:
		_attack_dir = to_predicted.normalized()


func _start_attack_animation() -> void:
	if _pattern != SNIPE and _pattern != TRAPS and _pattern != BARRAGE:
		super._start_attack_animation()
		return
	if _anim_sprite == null:
		return
	if not _play("cast" if _pattern == TRAPS else "attack"):
		return
	_hit_playing = false
	_fit_animation_to(telegraph_time + attack_active_time)


func _execute_attack() -> void:
	match _pattern:
		SNIPE:
			_caster.damage_multiplier = _effective_damage_multiplier()
			_snipe_second_done = false
			_fire_arrow(snipe_spell, _attack_dir)
			impact.emit(4.0)
		TRAPS:
			_caster.damage_multiplier = _effective_damage_multiplier()
			_spawn_traps()
		BARRAGE:
			_caster.damage_multiplier = _effective_damage_multiplier()
			_barrage_done = 0
		_:
			super._execute_attack()


func _state_attack() -> void:
	match _pattern:
		SNIPE:
			# Giai đoạn 2: mũi thứ hai ngắm lại sau một nhịp.
			if _phase >= 2 and not _snipe_second_done and _state_time >= 0.35:
				_snipe_second_done = true
				_update_attack_aim()
				_fire_arrow(snipe_spell, _attack_dir)
			super._state_attack()
		BARRAGE:
			var total := barrage_shots + (2 if _phase >= 2 else 0)
			while _barrage_done < total and _state_time >= float(_barrage_done) * barrage_interval:
				_barrage_done += 1
				_update_attack_aim()  # mỗi phát ngắm lại: người cứ chạy thẳng sẽ bị đón đầu
				_fire_arrow(barrage_spell, _attack_dir)
			if _state_time >= attack_active_time and _barrage_done >= total:
				_enter_state(State.RECOVERY)
		TRAPS:
			super._state_attack()
		_:
			super._state_attack()


func _fire_arrow(spell: SpellData, dir: Vector2) -> void:
	if spell == null:
		return
	_caster.set_aim(dir, global_position + dir * 100.0)
	_caster.cast(spell)


## Bẫy băng: cái đầu rơi vào chỗ Player SẼ đứng (đón đầu), các cái sau rải quanh (lệch về phía Player hay đi vòng).
## Mỗi vùng nổ tự vẽ vòng cảnh báo trong lúc chờ.
func _spawn_traps() -> void:
	if target == null or not is_instance_valid(target) or get_parent() == null or trap_spell == null:
		return
	var count := trap_count + (2 if _phase >= 2 else 0)
	var first := brain.predict_position(target.global_position, _target_velocity(), 1.0)
	var to_player := (target.global_position - global_position).normalized()
	var side := Vector2(-to_player.y, to_player.x) * signf(brain.strafe_bias)
	var multiplier := _effective_damage_multiplier()
	for i in count:
		var pos := first
		if i > 0:
			if brain.enabled and absf(brain.strafe_bias) > 0.3 and randf() < absf(brain.strafe_bias) * 0.5 * brain.strength:
				pos += side * randf_range(70.0, 160.0)
			else:
				pos += Vector2.from_angle(randf() * TAU) * randf_range(70.0, 190.0)
		pos = _clamp_to_arena(pos)
		var burst := SpellAreaBurst.new()
		burst.setup(trap_spell, &"enemy", self, multiplier)
		burst.delay_override = 0.95 + 0.15 * float(i)
		get_parent().add_child(burst)
		burst.global_position = pos


# ---------------------------------------------------------------- Cảnh báo
func _draw_extra_telegraph(extra_pattern: int, color: Color, progress: float) -> void:
	match extra_pattern:
		SNIPE:
			var length := 760.0
			var side := Vector2(-_attack_dir.y, _attack_dir.x) * (4.0 + 6.0 * (1.0 - progress))
			draw_colored_polygon(PackedVector2Array([side, _attack_dir * length + side, _attack_dir * length - side, -side]), Color(color, color.a * 0.45))
			draw_line(Vector2.ZERO, _attack_dir * length, Color(0, 0, 0, 0.85), 11.0)
			draw_line(Vector2.ZERO, _attack_dir * length, color, 6.0)
		BARRAGE:
			var length := barrage_spell.projectile_speed * 0.9 if barrage_spell != null else 400.0
			draw_line(_attack_dir * 24.0, _attack_dir * length, Color(0, 0, 0, 0.8), 9.0)
			draw_line(_attack_dir * 24.0, _attack_dir * length, color, 5.0)
			draw_arc(Vector2.ZERO, 40.0 + 20.0 * progress, _attack_dir.angle() - 0.5, _attack_dir.angle() + 0.5, 12, color, 3.0)
		TRAPS:
			draw_arc(Vector2.ZERO, 36.0 + 24.0 * progress, 0.0, TAU, 32, Color(0, 0, 0, 0.8), 9.0)
			draw_arc(Vector2.ZERO, 36.0 + 24.0 * progress, 0.0, TAU, 32, color, 5.0)


# ---------------------------------------------------------------- Triệu hồi CamoArcher
func _ready() -> void:
	# Phòng tuyết rất sáng: dùng đỏ thẫm (đang ngắm) và tím đậm (khoá mục tiêu) với độ đậm cao để thấy rõ vùng nguy hiểm.
	telegraph_color = Color(0.62, 0.0, 0.08, 1.0)
	telegraph_lock_color = Color(0.3, 0.0, 0.5, 1.0)
	telegraph_min_alpha = 0.85
	super._ready()


func activate() -> void:
	super.activate()
	_minion_timer = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _active or is_dead or _transitioning:
		return
	_minion_timer += delta
	if _minion_timer >= minion_interval:
		_minion_timer = 0.0
		_summon_minions()


func _summon_minions() -> void:
	var parent_node := get_parent()
	if minion_scene == null or parent_node == null:
		return
	var alive: Array[Node] = []
	for m in _minions:
		if is_instance_valid(m) and not bool(m.get("is_dead")):
			alive.append(m)
	_minions = alive
	var map := get_tree().get_first_node_in_group("map_generator") as MapGenerator
	for i in minions_per_wave:
		if _minions.size() >= max_minions:
			break
		var pos := _find_minion_position(map, i)
		var minion := minion_scene.instantiate() as Enemy
		if minion == null:
			push_error("LongbowBoss: minion_scene chưa gắn script Enemy.gd.")
			return
		minion.score_value = 0  # đệ tử không cho điểm
		parent_node.add_child(minion)
		minion.global_position = pos
		_minions.append(minion)
		CombatFx.spawn_impact(parent_node, death_vfx_folder, pos, Color(0.6, 0.85, 1.0), 2.8, 24.0, 50.0)
		minion_spawned.emit(minion)
	impact.emit(3.0)


## Vị trí đứng được (map xác nhận) cách Boss 90-200 px, ưu tiên phía xa Player.
func _find_minion_position(map: MapGenerator, index: int) -> Vector2:
	var away := Vector2.ZERO
	if target != null and is_instance_valid(target):
		away = (global_position - target.global_position).normalized()
	for attempt in 10:
		var base_angle := away.angle() if away != Vector2.ZERO else randf() * TAU
		var angle := base_angle + (index - 0.5) * 0.9 + randf_range(-0.9, 0.9) * float(attempt) / 5.0
		var pos := _clamp_to_arena(global_position + Vector2.from_angle(angle) * randf_range(90.0, 200.0))
		if map == null or map.is_spawnable(pos):
			return pos
	return global_position + Vector2.from_angle(randf() * TAU) * 60.0


func die() -> void:
	if is_dead:
		return
	_kill_minions()
	super.die()


func _kill_minions() -> void:
	var parent_node := get_parent()
	for m in _minions:
		if not is_instance_valid(m):
			continue
		if parent_node != null:
			CombatFx.spawn_impact(parent_node, death_vfx_folder, (m as Node2D).global_position, Color(0.6, 0.85, 1.0), 2.4, 24.0, 40.0)
		m.remove_from_group("enemies")
		m.queue_free()
	_minions.clear()
