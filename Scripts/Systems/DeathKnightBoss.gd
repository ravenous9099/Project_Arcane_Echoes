class_name DeathKnightBoss
extends Boss
## Boss level 2 "Hiệp sĩ tử thần". KẾ THỪA toàn bộ Boss.gd (2 giai đoạn, nối đòn, bộ não học hành vi người chơi, đổi giai đoạn, chết...),
## thêm ba đòn CẬN CHIẾN và việc TRIỆU HỒI đệ tử:
##   SPIN  : xoay kiếm quét vòng quanh người, hai nhịp liên tiếp (báo trước bằng vòng tròn).
##   COMBO : chém ba nhát liên tiếp hình quạt, mỗi nhát bước tới và ngắm lại Player (mỗi nhát đều có quạt cảnh báo ngắn).
##   LEAP  : bật nhảy tới chỗ Player (đón đầu) rồi đáp xuống gây vụ nổ (báo trước bằng vòng tròn tại điểm đáp).
## Các đòn của Boss level 1 (SLAM, FAN, CHARGE, METEORS, RING) vẫn dùng nhưng ít hơn; trọng số do _base_weights quyết định.
## Cứ mỗi minion_interval giây (mặc định 6) Boss triệu hồi minions_per_wave đệ tử (Paladin), tối đa max_minions con cùng lúc.

## Đệ tử mới xuất hiện: BossEncounter dùng để gắn phản hồi chiến đấu (âm thanh, hitstop...).
signal minion_spawned(minion: Node)

const SPIN: int = 5
const COMBO: int = 6
const LEAP: int = 7

const DK_TIMING: Dictionary = {
	SPIN: {"tele": 0.75, "lock": 0.25, "active": 0.85, "recover": 0.8, "gap": 0.4},
	COMBO: {"tele": 0.55, "lock": 0.2, "active": 1.3, "recover": 0.85, "gap": 0.4},
	LEAP: {"tele": 0.9, "lock": 0.35, "active": 0.7, "recover": 0.8, "gap": 0.45},
}
const DK_FOLLOWUPS: Dictionary = {
	Pattern.SLAM: [COMBO, Pattern.CHARGE],
	Pattern.FAN: [LEAP, Pattern.CHARGE],
	Pattern.CHARGE: [COMBO, SPIN, Pattern.SLAM],
	Pattern.METEORS: [LEAP, Pattern.CHARGE],
	Pattern.RING: [Pattern.CHARGE, LEAP],
	SPIN: [COMBO, Pattern.CHARGE],
	COMBO: [SPIN, LEAP],
	LEAP: [COMBO, SPIN, Pattern.SLAM],
}
## Thời điểm (giây kể từ khi đòn COMBO bắt đầu ra đòn) của từng nhát chém.
const COMBO_HIT_TIMES: Array[float] = [0.05, 0.6, 1.1]
## Một nhát được cảnh báo (vẽ quạt) trong khoảng này trước khi chém; 0.1s cuối hướng chém bị khóa.
const COMBO_WARN_TIME: float = 0.25
const COMBO_LOCK_TIME: float = 0.1

@export_group("Hiệp sĩ tử thần - đòn cận chiến")
## Vòng quét của SPIN (vùng nổ tức thì, đánh hai lần).
@export var spin_spell: SpellData
@export var spin_hit_times: Array[float] = [0.05, 0.45]
## Sát thương / tầm / nửa góc quạt / lực đẩy của mỗi nhát COMBO.
@export var combo_damage: float = 20.0
@export var combo_range: float = 112.0
@export_range(15.0, 90.0, 1.0) var combo_half_angle_deg: float = 52.0
@export var combo_knockback: float = 420.0
## Tốc độ bước tới của mỗi nhát (pixel/giây) và thời gian bước (giây).
@export var combo_step_speed: float = 330.0
@export var combo_step_time: float = 0.14
## Vụ nổ khi đáp xuống của LEAP.
@export var leap_spell: SpellData
@export var leap_max_distance: float = 360.0
@export var leap_time: float = 0.42
## Độ cao tối đa của cú nhảy (chỉ để nhìn, pixel).
@export var leap_height: float = 46.0

@export_group("Hiệp sĩ tử thần - triệu hồi")
## Scene đệ tử (Paladin).
@export var minion_scene: PackedScene
@export var minion_interval: float = 6.0
@export var minions_per_wave: int = 2
## Số đệ tử còn sống tối đa cùng lúc (tránh tràn màn hình nếu Player không diệt chúng).
@export var max_minions: int = 8

var _combo_hits_done: int = 0
var _spin_hits_done: int = 0
var _lunge_left: float = 0.0
var _leap_target: Vector2 = Vector2.ZERO
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO
var _minion_timer: float = 0.0
var _minions: Array[Node] = []


func _ready() -> void:
	super._ready()
	_leap_target = global_position


# ---------------------------------------------------------------- Hình ảnh và dữ liệu đòn
func _build_frames() -> SpriteFrames:
	var sheets := {"idle": "Idle", "move": move_animation, "hit": "TakeDamage", "die": "Die",
			"attack": "Melee", "cast": "CastSpell", "charge": "MeleeRun", "special": "Special1",
			"spin": "MeleeSpin", "combo": "Melee2", "leap": "FrontFlip"}
	var loops := {"idle": true, "move": true, "hit": false, "die": false,
			"attack": false, "cast": false, "charge": false, "special": false,
			"spin": false, "combo": false, "leap": false}
	return CharacterFrames.build(character_folder, sheets, loops, frame_size, anim_fps)


func _get_timing(pattern: int) -> Dictionary:
	if DK_TIMING.has(pattern):
		return DK_TIMING[pattern]
	return super._get_timing(pattern)


func _get_followups(pattern: int) -> Array:
	return DK_FOLLOWUPS.get(pattern, [])


func _pattern_allowed(pattern: int, dist: float) -> bool:
	match pattern:
		SPIN:
			return spin_spell != null and dist < spin_spell.area_radius + 45.0
		COMBO:
			return dist < combo_range + 140.0
		LEAP:
			return leap_spell != null and dist > 150.0
	return super._pattern_allowed(pattern, dist)


## Ưu tiên cận chiến: giảm đòn tầm xa của Boss level 1, thêm SPIN / COMBO / LEAP theo khoảng cách.
func _base_weights(dist: float) -> Dictionary:
	var weights := super._base_weights(dist)
	for ranged: int in [Pattern.FAN, Pattern.METEORS, Pattern.RING]:
		if weights.has(ranged):
			weights[ranged] = float(weights[ranged]) * 0.55
	if spin_spell != null and dist < spin_spell.area_radius + 45.0:
		weights[SPIN] = 3.5
	if dist < combo_range + 140.0:
		weights[COMBO] = 4.0 if dist < combo_range + 60.0 else 3.0
	if leap_spell != null and dist > 150.0:
		weights[LEAP] = 3.5 if _phase >= 2 else 3.0
	return weights


# ---------------------------------------------------------------- Ra đòn
func _start_attack_animation() -> void:
	var key := ""
	match _pattern:
		SPIN:
			key = "spin"
		COMBO:
			key = "combo"
		LEAP:
			key = "leap"
	if key.is_empty():
		super._start_attack_animation()
		return
	if _anim_sprite == null or not _play(key):
		return
	_hit_playing = false
	_fit_animation_to(telegraph_time + attack_active_time)


func _update_attack_aim() -> void:
	super._update_attack_aim()
	if _pattern == LEAP and target != null and is_instance_valid(target):
		# Điểm đáp: chỗ Player SẼ đứng (bộ não đón đầu), không xa quá leap_max_distance, không ra ngoài đấu trường.
		var predicted := brain.predict_position(target.global_position, _target_velocity(), leap_time + 0.3)
		var offset := predicted - global_position
		if offset.length() > leap_max_distance:
			predicted = global_position + offset.normalized() * leap_max_distance
		_leap_target = _clamp_to_arena(predicted)


func _execute_attack() -> void:
	match _pattern:
		SPIN:
			_spin_hits_done = 0
			_caster.damage_multiplier = _effective_damage_multiplier()
		COMBO:
			_combo_hits_done = 0
			_lunge_left = 0.0
			_caster.damage_multiplier = _effective_damage_multiplier()
		LEAP:
			_leap_from = global_position
			_leap_to = _leap_target
			_caster.damage_multiplier = _effective_damage_multiplier()
		_:
			super._execute_attack()


func _state_attack() -> void:
	match _pattern:
		SPIN:
			_process_spin()
		COMBO:
			_process_combo()
		LEAP:
			_process_leap()
		_:
			super._state_attack()


func _process_spin() -> void:
	# Vừa quay vừa tiến chậm về phía Player.
	if target != null and is_instance_valid(target):
		_desired_velocity = (target.global_position - global_position).normalized() * move_speed * 0.8 * _speed_multiplier()
	while _spin_hits_done < spin_hit_times.size() and _state_time >= spin_hit_times[_spin_hits_done]:
		_spin_hits_done += 1
		_caster.set_aim(_attack_dir, global_position)
		_caster.cast(spin_spell)
		impact.emit(5.0)
	if _state_time >= attack_active_time:
		_enter_state(State.RECOVERY)


func _process_combo() -> void:
	var delta := get_physics_process_delta_time()
	if _combo_hits_done < COMBO_HIT_TIMES.size():
		var hit_time: float = COMBO_HIT_TIMES[_combo_hits_done]
		if _combo_hits_done > 0 and _state_time < hit_time - COMBO_LOCK_TIME:
			_update_attack_aim()  # nhát sau ngắm lại Player cho tới 0.1s trước khi chém
		if _state_time >= hit_time:
			_combo_hits_done += 1
			_combo_slash()
	if _lunge_left > 0.0:
		_lunge_left -= delta
		_desired_velocity = _attack_dir * combo_step_speed * _speed_multiplier()
	queue_redraw()  # vẽ quạt cảnh báo của nhát kế tiếp
	if _state_time >= attack_active_time:
		_enter_state(State.RECOVERY)


## Một nhát chém: bước tới, gây sát thương MỘT lần cho Player nằm trong quạt (tầm combo_range, nửa góc combo_half_angle_deg).
func _combo_slash() -> void:
	_lunge_left = combo_step_time
	impact.emit(4.0)
	if target == null or not is_instance_valid(target) or bool(target.get("is_dead")):
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist > combo_range + 14.0:  # + bán kính thân Player
		return
	if dist > 24.0 and absf(_attack_dir.angle_to(to_target.normalized())) > deg_to_rad(combo_half_angle_deg):
		return
	DamageInfo.create(combo_damage * _effective_damage_multiplier(), DamageInfo.Type.PHYSICAL, self, _attack_dir * combo_knockback).apply_to(target)


func _process_leap() -> void:
	var t := clampf(_state_time / maxf(leap_time, 0.05), 0.0, 1.0)
	var remaining := _leap_to - global_position
	if t < 1.0 and remaining.length() > 10.0:
		_desired_velocity = remaining.normalized() * (_leap_to - _leap_from).length() / maxf(leap_time, 0.05)
	if _anim_sprite != null:
		_anim_sprite.position.y = sprite_offset.y - sin(PI * t) * leap_height  # độ cao nhảy (chỉ hình ảnh)
	if t >= 1.0 or remaining.length() <= 10.0:
		_land()


func _land() -> void:
	if _anim_sprite != null:
		_anim_sprite.position.y = sprite_offset.y
	_caster.set_aim(_attack_dir, global_position)
	_caster.cast(leap_spell)
	impact.emit(10.0)
	_enter_state(State.RECOVERY)


func _enter_state(new_state: State) -> void:
	# Rời khỏi trạng thái ra đòn giữa chừng (choáng, đổi giai đoạn...): trả hình về mặt đất.
	if _anim_sprite != null and new_state != State.ATTACK and _pattern == LEAP:
		_anim_sprite.position.y = sprite_offset.y
	super._enter_state(new_state)


# ---------------------------------------------------------------- Cảnh báo
func _draw_extra_telegraph(extra_pattern: int, color: Color, progress: float) -> void:
	match extra_pattern:
		SPIN:
			var radius := spin_spell.area_radius
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, color, 3.0)
			draw_circle(Vector2.ZERO, radius * progress, Color(color, color.a * 0.45))
		COMBO:
			_draw_cone(color, 0.3 + 0.5 * progress)
		LEAP:
			var landing := to_local(_leap_target)
			var r := leap_spell.area_radius
			draw_line(Vector2.ZERO, landing, Color(color, color.a * 0.6), 2.0)
			draw_arc(landing, r, 0.0, TAU, 48, color, 3.0)
			draw_circle(landing, r * progress, Color(color, color.a * 0.45))


## Quạt cảnh báo cho nhát chém kế tiếp trong lúc đang COMBO (hiện trong COMBO_WARN_TIME trước nhát, đỏ hơn khi đã khóa hướng).
func _draw() -> void:
	if not _transitioning and _state == State.ATTACK and _pattern == COMBO and _combo_hits_done < COMBO_HIT_TIMES.size() and _combo_hits_done > 0:
		var hit_time: float = COMBO_HIT_TIMES[_combo_hits_done]
		var until := hit_time - _state_time
		if until <= COMBO_WARN_TIME and until > 0.0:
			var locked := until <= COMBO_LOCK_TIME
			_draw_cone(telegraph_lock_color if locked else telegraph_color, 0.35 + 0.5 * (1.0 - until / COMBO_WARN_TIME))
		return
	super._draw()


func _draw_cone(color: Color, strength: float) -> void:
	var half := deg_to_rad(combo_half_angle_deg)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		pts.append(_attack_dir.rotated(lerpf(-half, half, float(i) / 12.0)) * combo_range)
	draw_colored_polygon(pts, Color(color, 0.22 * strength))
	var edge := Color(color, clampf(strength, 0.2, 0.9))
	draw_line(Vector2.ZERO, pts[1], edge, 2.0)
	draw_line(Vector2.ZERO, pts[pts.size() - 1], edge, 2.0)
	draw_arc(Vector2.ZERO, combo_range, _attack_dir.angle() - half, _attack_dir.angle() + half, 20, edge, 2.0)


# ---------------------------------------------------------------- Triệu hồi đệ tử
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
			push_error("DeathKnightBoss: minion_scene chưa gắn script Enemy.gd.")
			return
		minion.score_value = 0  # đệ tử không cho điểm
		parent_node.add_child(minion)
		minion.global_position = pos
		_minions.append(minion)
		CombatFx.spawn_impact(parent_node, death_vfx_folder, pos, Color(0.8, 0.3, 1.0), 2.8, 24.0, 50.0)
		minion_spawned.emit(minion)
	impact.emit(4.0)


## Vị trí đứng được (map xác nhận) cách Boss 90-170 px, ưu tiên phía xa Player một chút để không "dán" vào mặt người chơi.
func _find_minion_position(map: MapGenerator, index: int) -> Vector2:
	var away := Vector2.ZERO
	if target != null and is_instance_valid(target):
		away = (global_position - target.global_position).normalized()
	for attempt in 10:
		var base_angle := away.angle() if away != Vector2.ZERO else randf() * TAU
		var angle := base_angle + (index - 0.5) * 0.9 + randf_range(-0.7, 0.7) * float(attempt) / 5.0
		var pos := _clamp_to_arena(global_position + Vector2.from_angle(angle) * randf_range(90.0, 170.0))
		if map == null or map.is_spawnable(pos):
			return pos
	return global_position + Vector2.from_angle(randf() * TAU) * 60.0


func die() -> void:
	if is_dead:
		return
	_kill_minions()
	super.die()


## Boss chết: đệ tử tan biến cùng Boss (không cho điểm, không phản hồi chiến đấu).
func _kill_minions() -> void:
	var parent_node := get_parent()
	for m in _minions:
		if not is_instance_valid(m):
			continue
		if parent_node != null:
			CombatFx.spawn_impact(parent_node, death_vfx_folder, (m as Node2D).global_position, Color(0.8, 0.3, 1.0), 2.4, 24.0, 40.0)
		m.remove_from_group("enemies")
		m.queue_free()
	_minions.clear()
