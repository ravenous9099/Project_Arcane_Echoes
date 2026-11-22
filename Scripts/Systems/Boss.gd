class_name Boss
extends Enemy
## Boss "Chúa Tể Bóng Tối". Kế thừa Enemy để dùng lại máu, đẩy lùi, animation, hiển thị sát thương, cái chết;
## chỉ ghi đè phần hành vi: 5 đòn đánh có báo trước, 2 giai đoạn, nối đòn, và BỘ NÃO thích nghi (BossBrain).
##
## Vòng lặp chiến đấu (dùng lại máy trạng thái của Enemy):
##   IDLE (chờ BossEncounter gọi activate()) -> CHASE (đứng cách Player ~preferred_distance) -> chọn đòn
##   -> ATTACK_PREP (BÁO TRƯỚC: vẽ vùng/làn nguy hiểm; hướng khóa ở cuối) -> ATTACK -> RECOVERY (đứng yên, SƠ HỞ)
##   -> (có thể NỐI ĐÒN liền, không nghỉ) hoặc CHASE...
## Đòn đánh:
##   SLAM    : vòng nổ quanh người Boss (chỉ khi Player ở gần).
##   FAN     : chùm đạn tỏa quạt; giai đoạn 2 bắn thêm đợt hai ngắm lại theo vị trí Player.
##   CHARGE  : lao thẳng theo hướng đã khóa; đâm vào tường/cột thì choáng thêm một lúc.
##   METEORS : nhiều vòng cảnh báo rơi quanh (và đón đầu) Player, nổ lần lượt.
##   RING    : vòng đạn tỏa mọi hướng, hai đợt so le (chỉ giai đoạn 2).
## Độ khó: nhịp đánh dồn dập (nghỉ ngắn, áp lực tăng dần nếu Player không bị trúng), nối đòn liền, ngắm đón đầu,
## nhử khi Player hay lướt sớm, đổi tỉ lệ chọn đòn theo thói quen Player (xem BossBrain).
## Mọi con số "cảm giác" (nhịp, nối đòn, học) nằm trong CombatTuning (Resources/combat_tuning.tres).

## Phát ra khi Boss đổi sang giai đoạn mới (phase = 2).
signal phase_changed(phase: int)
## Cú va chạm mạnh (đập đất, đâm tường, đổi giai đoạn, chết): Encounter dùng để rung màn hình. strength tính bằng pixel.
signal impact(strength: float)
## Boss bắt đầu báo trước một đòn (pattern = giá trị enum Pattern): dùng cho âm thanh cảnh báo.
signal telegraph_started(pattern: int)

enum Pattern { SLAM, FAN, CHARGE, METEORS, RING }

## Thời gian từng đòn (giây): tele = báo trước, lock = khoảng cuối báo trước mà hướng bị KHÓA, active = đòn diễn ra,
## recover = hồi sau đòn (đứng yên, Player nên phản công), gap = nghỉ di chuyển trước đòn kế.
const TIMING: Dictionary = {
	Pattern.SLAM: {"tele": 0.8, "lock": 0.3, "active": 0.2, "recover": 0.65, "gap": 0.45},
	Pattern.FAN: {"tele": 0.7, "lock": 0.25, "active": 0.2, "recover": 0.5, "gap": 0.4},
	Pattern.CHARGE: {"tele": 0.85, "lock": 0.35, "active": 0.6, "recover": 0.75, "gap": 0.45},
	Pattern.METEORS: {"tele": 0.45, "lock": 0.0, "active": 0.5, "recover": 0.7, "gap": 0.5},
	Pattern.RING: {"tele": 0.8, "lock": 0.8, "active": 0.6, "recover": 0.85, "gap": 0.45},
}
## Đòn nào có thể nối tiếp sau đòn nào (bổ trợ nhau, tránh nối cùng loại).
const FOLLOWUPS: Dictionary = {
	Pattern.SLAM: [Pattern.FAN, Pattern.CHARGE],
	Pattern.FAN: [Pattern.CHARGE, Pattern.SLAM],
	Pattern.CHARGE: [Pattern.SLAM, Pattern.FAN, Pattern.METEORS],
	Pattern.METEORS: [Pattern.FAN, Pattern.CHARGE],
	Pattern.RING: [Pattern.CHARGE, Pattern.FAN],
}
## Thời gian mỗi cửa sổ theo dõi kết quả một đòn thêm sau khi nó kết thúc (thiên thạch nổ trễ hơn nên cần lâu hơn).
const RESULT_GRACE: float = 0.4
const RESULT_GRACE_METEORS: float = 1.9

@export_group("Boss")
## Tên hiện trên thanh máu và thông báo.
@export var boss_title: String = "CHÚA TỂ BÓNG TỐI"
## Boss sang giai đoạn 2 khi máu còn bằng hoặc dưới tỉ lệ này.
@export_range(0.1, 0.9, 0.05) var phase2_health_ratio: float = 0.5
@export var phase2_speed_multiplier: float = 1.3
## Giai đoạn 2: thời gian nghỉ giữa các đòn nhân với hệ số này (nhỏ hơn 1 = đánh dồn dập hơn).
@export_range(0.2, 1.0, 0.05) var phase2_gap_multiplier: float = 0.5
## Thời gian Boss miễn nhiễm và gầm lên khi đổi giai đoạn (giây).
@export var transition_time: float = 2.2
## Nhân sát thương mọi đòn của Boss (Encounter tăng theo vòng chơi).
@export var damage_multiplier: float = 1.0
## Khoảng cách Boss muốn đứng cách Player (pixel).
@export var preferred_distance: float = 170.0
## Số đòn nối liền tối đa (không nghỉ) trong mỗi giai đoạn.
@export var max_combo_chain_phase1: int = 1
@export var max_combo_chain_phase2: int = 2
## Giai đoạn 2: đợt đạn FAN thứ hai bắn sau bấy nhiêu giây, ngắm lại theo vị trí Player lúc đó.
@export var fan_second_volley_delay: float = 0.28

@export_group("Đòn đánh của Boss")
@export var slam_spell: SpellData
@export var fan_spell: SpellData
@export var ring_spell: SpellData
@export var meteor_spell: SpellData
@export var fan_bolts: int = 5
@export var fan_spread_degrees: float = 56.0
## Số viên mỗi đợt của đòn RING (2 đợt so le nên tổng gấp đôi). 10 để còn làn an toàn ở tầm trung; tăng lên 14 thì chỉ còn cách lướt.
@export var ring_bolts: int = 10
@export var meteor_count: int = 6
@export var charge_speed: float = 680.0
## Thời gian lao tối đa (giây). Quãng đường lao = charge_speed * charge_max_time.
@export var charge_max_time: float = 0.6
@export var charge_damage: float = 34.0
@export var charge_knockback: float = 520.0
## Choáng thêm (giây) khi đâm vào tường/cột đá: cơ hội phản công.
@export var charge_wall_stun_time: float = 1.0

@export_group("Hiệu ứng chết")
@export_dir var death_vfx_folder: String = "res://Assets/Spell/Effect Bullet Impact Explosion 32x32/Sliced/Purple/e12"
@export var death_vfx_scale: float = 5.0

## Bộ não thích nghi. BossEncounter có thể gán brain dùng chung của cả lượt chơi (Boss nhớ người chơi qua các vòng); nếu để trống Boss tự tạo.
var brain: BossBrain = null

var _phase: int = 1
var _active: bool = false
var _transitioning: bool = false
var _transition_elapsed: float = 0.0
var _shock_done: bool = false
var _pattern: int = Pattern.SLAM  # giá trị của enum Pattern (dùng int để khỏi phải ép kiểu)
var _last_pattern: int = -1
var _combo_chain: int = 0
var _charge_hit: bool = false
var _ring_second_done: bool = false
var _fan_second_done: bool = false
var _base_modulate: Color = Color.WHITE
var _arena_center: Vector2 = Vector2.ZERO
var _arena_radius: float = 0.0
var _arena_half_extents: Vector2 = Vector2.ZERO
var _clock: float = 0.0
var _watched_id: int = 0
var _windows: Array[Dictionary] = []  # theo dõi kết quả từng đòn: {pattern, expire, hit}


func _ready() -> void:
	assert(BossBrain.SLAM == Pattern.SLAM and BossBrain.FAN == Pattern.FAN and BossBrain.CHARGE == Pattern.CHARGE \
			and BossBrain.METEORS == Pattern.METEORS and BossBrain.RING == Pattern.RING, "BossBrain và Boss.Pattern lệch mã đòn")
	if brain == null:
		brain = BossBrain.new()
	drops_health = false
	super._ready()
	_caster.muzzle_distance = body_radius + 12.0
	_configure_brain()


## Boss chỉ bị ép choáng khi đang hoạt động và không đang đổi giai đoạn.
## Boss luôn rơi 100-120 vàng, chia thành nhiều đồng cho đẹp.
func _roll_gold() -> Vector2i:
	var tuning := CombatTuning.current()
	return Vector2i(randi_range(tuning.boss_gold_min, maxi(tuning.boss_gold_max, tuning.boss_gold_min)), 14)


func force_stun(duration: float) -> void:
	if not _active or _transitioning:
		return
	super.force_stun(duration)


func get_phase() -> int:
	return _phase


func is_active() -> bool:
	return _active


## Cho Boss biết đấu trường (tâm và bán kính, toạ độ thế giới) để thiên thạch không rơi ra ngoài.
## half_extents khác ZERO = đấu trường hình chữ nhật (level 4): giới hạn di chuyển là hình elip nửa trục half_extents thay vì hình tròn.
func configure_arena(center: Vector2, radius: float, half_extents: Vector2 = Vector2.ZERO) -> void:
	_arena_center = center
	_arena_radius = radius
	_arena_half_extents = half_extents


## BossEncounter gọi khi phần giới thiệu kết thúc: từ giờ Boss chịu sát thương và bắt đầu đánh.
func activate() -> void:
	_active = true
	_attack_cd = 0.8  # không đánh ngay lập tức


## Văn bản debug cho HUD: giai đoạn, đòn hiện tại, những gì Boss đã học.
func get_debug_text() -> String:
	var pattern_name := BossBrain.PATTERN_NAMES[_pattern] if _pattern >= 0 and _pattern < BossBrain.PATTERN_NAMES.size() else "-"
	return "BOSS giai đoạn %d | đòn %s | nối đòn %d | %s\n%s" % [_phase, pattern_name, _combo_chain, get_state_name(), brain.debug_text()]


## Thanh máu trên đầu bị tắt: Boss dùng thanh máu lớn của HUD.
func _setup_health_bar() -> void:
	pass


## Boss dùng hệ số máu riêng của CombatTuning (không dùng hệ số của Enemy thường).
func _apply_tuning() -> void:
	max_health *= CombatTuning.current().boss_health_multiplier


func _configure_brain() -> void:
	var tuning := CombatTuning.current()
	brain.enabled = tuning.boss_learning_enabled
	brain.strength = tuning.boss_learning_strength
	brain.pressure_cap = tuning.boss_pressure_max


func _build_frames() -> SpriteFrames:
	var sheets := {"idle": "Idle", "move": move_animation, "hit": "TakeDamage", "die": "Die",
			"attack": "Attack1", "cast": "CastSpell", "charge": "AttackRun", "special": "Special1"}
	var loops := {"idle": true, "move": true, "hit": false, "die": false,
			"attack": false, "cast": false, "charge": false, "special": false}
	return CharacterFrames.build(character_folder, sheets, loops, frame_size, anim_fps)


func _rest_color() -> Color:
	return _base_modulate


# ---------------------------------------------------------------- Nhận sát thương, đổi giai đoạn, chết
func take_damage(amount: float, info: DamageInfo = null) -> void:
	# Miễn nhiễm khi chưa bắt đầu (đang giới thiệu) và khi đang gầm lên đổi giai đoạn.
	if is_dead or _transitioning or not _active:
		return
	super.take_damage(amount, info)
	if not is_dead and _phase == 1 and health <= max_health * phase2_health_ratio:
		_begin_transition()


func die() -> void:
	if is_dead:
		return
	_transitioning = false
	impact.emit(14.0)
	_death_effects()
	_clear_attacks()
	super.die()


func _flash() -> void:
	if _anim_sprite == null:
		return
	_anim_sprite.modulate = Color(1.0, 0.6, 0.6)
	create_tween().tween_property(_anim_sprite, "modulate", _base_modulate, 0.15)


func _begin_transition() -> void:
	_transitioning = true
	_transition_elapsed = 0.0
	_shock_done = false
	_phase = 2
	_combo_chain = 0
	_windows.clear()
	_caster.reset()
	_desired_velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_clear_attacks()
	_state = State.CHASE  # trạng thái FSM không dùng trong lúc gầm; đặt về mức an toàn
	_state_time = 0.0
	_hit_playing = false
	_base_modulate = Color(1.0, 0.72, 0.72)
	_play("special")
	_fit_animation_to(transition_time)
	phase_changed.emit(_phase)
	impact.emit(6.0)
	queue_redraw()


func _process_transition(delta: float) -> void:
	_find_target_if_needed()
	_transition_elapsed += delta
	velocity = Vector2.ZERO
	move_and_slide()
	if _anim_sprite != null:  # nhấp nháy đỏ - trắng
		var pulse := 0.5 + 0.5 * sin(_transition_elapsed * 22.0)
		_anim_sprite.modulate = Color(1.0, 0.45 + 0.55 * pulse, 0.45 + 0.55 * pulse)
	if not _shock_done and _transition_elapsed >= transition_time * 0.45:
		_shock_done = true
		_shockwave()
	if _transition_elapsed >= transition_time:
		_end_transition()
	queue_redraw()


## Sóng xung kích đẩy Player ra xa (không gây sát thương, chỉ tạo khoảng thở) và xóa đạn còn bay.
func _shockwave() -> void:
	impact.emit(12.0)
	_clear_attacks()
	if target != null and is_instance_valid(target) and target.has_method("apply_knockback"):
		var away := (target.global_position - global_position).normalized()
		target.call("apply_knockback", away * 650.0)


func _end_transition() -> void:
	_transitioning = false
	if _anim_sprite != null:
		_anim_sprite.modulate = _base_modulate
	_attack_cd = 0.7
	_last_pattern = -1
	_enter_state(State.CHASE)
	queue_redraw()


func _clear_attacks() -> void:
	for node in get_tree().get_nodes_in_group("enemy_attacks"):
		node.queue_free()


## Nhiều vụ nổ nhỏ nối tiếp quanh Boss lúc chết.
func _death_effects() -> void:
	var fx_parent := get_parent()
	if fx_parent == null:
		return
	for i in 7:
		var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)
		if i == 0:
			_spawn_death_fx(fx_parent, pos)
		else:
			get_tree().create_timer(i * 0.14).timeout.connect(_spawn_death_fx.bind(fx_parent, pos))


func _spawn_death_fx(fx_parent: Node, pos: Vector2) -> void:
	CombatFx.spawn_impact(fx_parent, death_vfx_folder, pos, Color(0.8, 0.3, 1.0), death_vfx_scale, 24.0, 90.0)


# ---------------------------------------------------------------- Quan sát Player (cho bộ não)
func _find_target_if_needed() -> void:
	super._find_target_if_needed()
	if target != null and is_instance_valid(target) and target.get_instance_id() != _watched_id:
		_watched_id = target.get_instance_id()
		if target.has_signal("damaged"):
			target.connect("damaged", _on_player_damaged)
		if target.has_signal("dash_started"):
			target.connect("dash_started", _on_player_dash)


func _on_player_damaged(_amount: float, _health_left: float) -> void:
	brain.register_player_hit()
	# Gán cho đòn bắt đầu gần đây nhất còn cửa sổ theo dõi.
	for i in range(_windows.size() - 1, -1, -1):
		if _clock <= float(_windows[i]["expire"]):
			_windows[i]["hit"] = true
			break


func _on_player_dash(_direction: Vector2) -> void:
	brain.register_player_dash(_state == State.ATTACK_PREP)


func _target_velocity() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	var v: Variant = target.get("velocity")
	return v as Vector2 if v is Vector2 else Vector2.ZERO


func _observe_player(delta: float) -> void:
	if not _active or is_dead or target == null or not is_instance_valid(target) or bool(target.get("is_dead")):
		return
	var max_hp := maxf(float(target.get("max_health")), 1.0)
	brain.observe(delta, global_position, target.global_position, _target_velocity(), float(target.get("health")) / max_hp)


func _open_window(pattern: int) -> void:
	var grace := RESULT_GRACE_METEORS if pattern == Pattern.METEORS else RESULT_GRACE
	_windows.append({"pattern": pattern, "expire": _clock + telegraph_time + attack_active_time + recovery_time + grace, "hit": false})


## Đóng các cửa sổ đã hết hạn và báo kết quả (trúng/né) cho bộ não.
func _expire_windows() -> void:
	for i in range(_windows.size() - 1, -1, -1):
		if _clock > float(_windows[i]["expire"]):
			brain.register_attack_result(int(_windows[i]["pattern"]), bool(_windows[i]["hit"]))
			_windows.remove_at(i)


# ---------------------------------------------------------------- Vòng lặp hành vi
func _physics_process(delta: float) -> void:
	_clock += delta
	_configure_brain()
	if _transitioning:
		_process_transition(delta)
		return
	super._physics_process(delta)
	_observe_player(delta)
	_expire_windows()


func _speed_multiplier() -> float:
	return phase2_speed_multiplier if _phase >= 2 else 1.0


## Nhịp đánh: áp lực của bộ não (lâu không bị trúng thì tăng) nhân hệ số nhịp trong CombatTuning. Lớn hơn 1 = nghỉ ít hơn.
func _pace() -> float:
	return clampf(brain.pressure * CombatTuning.current().boss_pace_multiplier, 0.6, 2.2)


## Boss không tự phát hiện Player: đứng yên cho tới khi BossEncounter gọi activate().
func _state_idle() -> void:
	if _active and _target_in_range(1.0e9):
		_enter_state(State.CHASE)


func _state_chase() -> void:
	if not _target_in_range(1.0e9):
		_enter_state(State.IDLE)
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target / dist if dist > 0.001 else Vector2.DOWN
	if _attack_cd <= 0.0:
		_combo_chain = 0
		_start_pattern(_choose_pattern(dist), false)
		return
	# Giữ khoảng cách vừa phải: tiến lại nếu xa, lùi nhẹ nếu Player áp sát.
	if dist > preferred_distance + 30.0:
		_desired_velocity = dir * move_speed * _speed_multiplier()
	elif dist < preferred_distance - 60.0:
		_desired_velocity = -dir * move_speed * 0.6 * _speed_multiplier()


## Trọng số gốc của từng đòn theo khoảng cách và giai đoạn (trước khi bộ não điều chỉnh).
func _base_weights(dist: float) -> Dictionary:
	var weights: Dictionary = {}
	# SLAM chỉ khi Player thật sự trong tầm vòng nổ (bán kính + thân Player), không thì đòn thành vô hại.
	if slam_spell != null and dist < slam_spell.area_radius + 25.0:
		weights[Pattern.SLAM] = 3.0
	weights[Pattern.FAN] = 2.5
	if dist > 140.0:
		weights[Pattern.CHARGE] = 3.0 if _phase >= 2 else 2.5
	weights[Pattern.METEORS] = 3.0 if _phase >= 2 else 2.0
	if _phase >= 2:
		weights[Pattern.RING] = 2.5
	return weights


## Chọn đòn tiếp theo: trọng số gốc -> bỏ đòn vừa dùng -> bộ não điều chỉnh -> thỉnh thoảng chọn ngẫu nhiên đều cho khó đoán.
func _choose_pattern(dist: float) -> int:
	var weights := _base_weights(dist)
	if weights.size() > 1:
		weights.erase(_last_pattern)  # không lặp lại đòn vừa rồi
	var adjusted := brain.adjust_weights(weights)
	var keys: Array = adjusted.keys()
	if brain.enabled and brain.strength > 0.0 and keys.size() > 1 and randf() < BossBrain.EXPLORE_CHANCE * brain.strength:
		return int(keys[randi() % keys.size()])
	var total := 0.0
	for w: float in adjusted.values():
		total += w
	var roll := randf() * total
	var chosen: int = int(keys[0])
	for key: int in keys:
		roll -= float(adjusted[key])
		if roll <= 0.0:
			chosen = key
			break
	return chosen


## Đặt thời gian theo đòn và giai đoạn rồi vào báo trước. combo = true: nối liền, không có thời gian nghỉ trước đòn.
func _start_pattern(pattern: int, combo: bool) -> void:
	_pattern = pattern
	_last_pattern = pattern
	var t: Dictionary = _get_timing(pattern)
	var phase2 := _phase >= 2
	var pace := _pace()
	telegraph_time = float(t["tele"]) * (0.9 if phase2 else 1.0)
	if pattern == Pattern.SLAM or pattern == Pattern.CHARGE:
		telegraph_time += brain.get_feint_delay()  # Player hay lướt sớm: nhử thêm một chút
	telegraph_time = maxf(telegraph_time, CombatTuning.current().min_telegraph_time)
	aim_lock_time = minf(float(t["lock"]), telegraph_time)
	attack_active_time = float(t["active"]) + (0.2 if pattern == Pattern.FAN and phase2 else 0.0)
	recovery_time = maxf(float(t["recover"]) * (0.8 if phase2 else 1.0) / pace, 0.35)
	var gap := 0.0 if combo else float(t["gap"]) * (phase2_gap_multiplier if phase2 else 1.0) / pace
	attack_cooldown = attack_active_time + recovery_time + gap
	_fan_second_done = false
	_open_window(pattern)
	telegraph_started.emit(pattern)
	_enter_state(State.ATTACK_PREP)


## Bảng thời gian của một đòn. Lớp con (Boss có đòn riêng) ghi đè để thêm đòn mới.
func _get_timing(pattern: int) -> Dictionary:
	return TIMING[pattern]


## Các đòn có thể nối tiếp sau một đòn. Lớp con ghi đè khi có đòn mới.
func _get_followups(pattern: int) -> Array:
	return FOLLOWUPS.get(pattern, [])


## Đòn này có dùng được ở khoảng cách dist không (dùng cho nối đòn). Lớp con mở rộng cho đòn riêng.
func _pattern_allowed(pattern: int, dist: float) -> bool:
	if pattern == Pattern.SLAM:
		return slam_spell != null and dist < slam_spell.area_radius + 25.0
	if pattern == Pattern.CHARGE:
		return dist > 140.0
	return true


## Sau khi hồi xong, có thể nối ngay một đòn bổ trợ (không nghỉ) với xác suất phụ thuộc giai đoạn và áp lực.
func _state_recovery() -> void:
	if _state_time >= recovery_time:
		if _try_combo():
			return
		_combo_chain = 0
	super._state_recovery()


func _try_combo() -> bool:
	if not _target_in_range(1.0e9):
		return false
	var max_chain := max_combo_chain_phase2 if _phase >= 2 else max_combo_chain_phase1
	if _combo_chain >= max_chain:
		return false
	var tuning := CombatTuning.current()
	var base_chance := tuning.boss_combo_chance_phase2 if _phase >= 2 else tuning.boss_combo_chance_phase1
	if randf() >= base_chance * clampf(brain.pressure, 0.85, 1.35):
		return false
	var dist := global_position.distance_to(target.global_position)
	var options: Array[int] = []
	for p: int in _get_followups(_last_pattern):
		if _pattern_allowed(p, dist):
			options.append(p)
	if options.is_empty():
		return false
	_combo_chain += 1
	_start_pattern(options[randi() % options.size()], true)
	return true


## Ngắm: FAN và CHARGE đón đầu theo hướng đi của Player (mức đón do bộ não quyết định).
func _update_attack_aim() -> void:
	super._update_attack_aim()
	if target == null or not is_instance_valid(target):
		return
	var speed := 0.0
	match _pattern:
		Pattern.FAN:
			speed = fan_spell.projectile_speed if fan_spell != null else 0.0
		Pattern.CHARGE:
			speed = charge_speed
	if speed <= 0.0:
		return
	var dist := global_position.distance_to(target.global_position)
	var predicted := brain.predict_position(target.global_position, _target_velocity(), clampf(dist / speed, 0.0, 0.6))
	var to_predicted := predicted - global_position
	if to_predicted.length_squared() > 1.0:
		_attack_dir = to_predicted.normalized()


func _start_attack_animation() -> void:
	if _anim_sprite == null:
		return
	var key := "attack"
	match _pattern:
		Pattern.FAN, Pattern.METEORS:
			key = "cast"
		Pattern.RING:
			key = "special"
		Pattern.CHARGE:
			key = "charge"
	if not _play(key):
		return
	_hit_playing = false
	_fit_animation_to(telegraph_time + attack_active_time)


func _effective_damage_multiplier() -> float:
	return damage_multiplier * CombatTuning.current().boss_damage_multiplier


func _execute_attack() -> void:
	_caster.damage_multiplier = _effective_damage_multiplier()
	match _pattern:
		Pattern.SLAM:
			_caster.set_aim(_attack_dir, global_position)
			_caster.cast(slam_spell)
			impact.emit(7.0)
		Pattern.FAN:
			_fire_fan()
		Pattern.CHARGE:
			_charge_hit = false  # chuyển động nằm trong _state_attack
		Pattern.METEORS:
			_spawn_meteors()
		Pattern.RING:
			_fire_ring(0.0)
			_ring_second_done = false


func _state_attack() -> void:
	match _pattern:
		Pattern.CHARGE:
			_process_charge()
		Pattern.RING:
			# Đợt đạn thứ hai so le với đợt đầu.
			if not _ring_second_done and _state_time >= 0.35:
				_ring_second_done = true
				_fire_ring(PI / float(ring_bolts))
			super._state_attack()
		Pattern.FAN:
			# Giai đoạn 2: đợt hai ngắm lại theo vị trí Player lúc này (trừng phạt người cứ đi vòng).
			if _phase >= 2 and not _fan_second_done and _state_time >= fan_second_volley_delay:
				_fan_second_done = true
				_update_attack_aim()
				_fire_fan()
			super._state_attack()
		_:
			super._state_attack()


func _process_charge() -> void:
	_desired_velocity = _attack_dir * charge_speed * _speed_multiplier()
	# Gây sát thương MỘT lần khi chạm Player.
	if not _charge_hit and target != null and is_instance_valid(target) \
			and global_position.distance_to(target.global_position) <= body_radius + 18.0:
		_charge_hit = true
		DamageInfo.create(charge_damage * _effective_damage_multiplier(), DamageInfo.Type.PHYSICAL, self, _attack_dir * charge_knockback).apply_to(target)
	# Kết thúc: hết thời gian lao, hoặc bị tường/cột chặn (vận tốc thực tế tụt mạnh).
	var blocked := _state_time > 0.12 and get_real_velocity().length() < charge_speed * 0.35
	if blocked or _state_time >= charge_max_time:
		if blocked:
			recovery_time += charge_wall_stun_time  # đâm vào tường: choáng thêm
			impact.emit(9.0)
		_enter_state(State.RECOVERY)


func _fire_fan() -> void:
	_caster.damage_multiplier = _effective_damage_multiplier()
	for dir in _fan_directions():
		_caster.set_aim(dir, global_position + dir * 100.0)
		_caster.cast(fan_spell)


## Các hướng đạn của đòn FAN. Dùng chung cho vẽ cảnh báo và bắn nên cảnh báo luôn khớp đạn thật.
func _fan_directions() -> Array[Vector2]:
	var count := fan_bolts + (2 if _phase >= 2 else 0)
	var spread := deg_to_rad(fan_spread_degrees)
	var out: Array[Vector2] = []
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		out.append(_attack_dir.rotated(lerpf(-spread * 0.5, spread * 0.5, t)))
	return out


func _fire_ring(angle_offset: float) -> void:
	_caster.damage_multiplier = _effective_damage_multiplier()
	for i in ring_bolts:
		var dir := Vector2.from_angle(TAU * float(i) / float(ring_bolts) + angle_offset)
		_caster.set_aim(dir, global_position + dir * 100.0)
		_caster.cast(ring_spell)


## Thiên thạch: viên đầu rơi vào chỗ Player SẼ đứng (đón đầu), các viên sau rải quanh, lệch về phía Player hay đi vòng.
## Mỗi vùng nổ tự vẽ vòng cảnh báo trong lúc chờ.
func _spawn_meteors() -> void:
	if target == null or not is_instance_valid(target) or get_parent() == null:
		return
	var count := meteor_count + (3 if _phase >= 2 else 0)
	var first := brain.predict_position(target.global_position, _target_velocity(), 1.0)
	var to_player := (target.global_position - global_position).normalized()
	var side := Vector2(-to_player.y, to_player.x) * signf(brain.strafe_bias)
	var multiplier := _effective_damage_multiplier()
	for i in count:
		var pos := first
		if i > 0:
			if brain.enabled and absf(brain.strafe_bias) > 0.3 and randf() < absf(brain.strafe_bias) * 0.5 * brain.strength:
				pos += side * randf_range(60.0, 170.0) + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 50.0)
			else:
				pos += Vector2.from_angle(randf() * TAU) * randf_range(60.0, 240.0)
		pos = _clamp_to_arena(pos)
		var burst := SpellAreaBurst.new()
		burst.setup(meteor_spell, &"enemy", self, multiplier)
		burst.delay_override = 1.0 + 0.12 * float(i)
		get_parent().add_child(burst)
		burst.global_position = pos


func _clamp_to_arena(pos: Vector2) -> Vector2:
	if _arena_radius <= 0.0:
		return pos
	var offset := pos - _arena_center
	if _arena_half_extents != Vector2.ZERO:
		var scaled := Vector2(offset.x / (_arena_half_extents.x * 0.9), offset.y / (_arena_half_extents.y * 0.9))
		return pos if scaled.length() <= 1.0 else _arena_center + offset / scaled.length()
	var limit := _arena_radius * 0.9
	return pos if offset.length() <= limit else _arena_center + offset.normalized() * limit


# ---------------------------------------------------------------- Vẽ cảnh báo
func _draw() -> void:
	if _transitioning:
		var k := clampf(_transition_elapsed / transition_time, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 40.0 + 380.0 * k, 0.0, TAU, 72, Color(1.0, 0.3, 0.2, 1.0 - k), 6.0)
		draw_arc(Vector2.ZERO, 20.0 + 260.0 * k, 0.0, TAU, 72, Color(1.0, 0.8, 0.3, 1.0 - k), 3.0)
		return
	if _state == State.ATTACK_PREP:
		_draw_pattern_telegraph()
		return
	super._draw()


func _draw_pattern_telegraph() -> void:
	var progress := clampf(_state_time / maxf(telegraph_time, 0.01), 0.0, 1.0)
	var locked := _state_time >= telegraph_time - aim_lock_time
	var color := telegraph_lock_color if locked else telegraph_color
	color.a = telegraph_min_alpha + (0.75 - telegraph_min_alpha) * progress
	match _pattern:
		Pattern.SLAM:
			var r := slam_spell.area_radius
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, color, 3.0)
			draw_circle(Vector2.ZERO, r * progress, Color(color, color.a * 0.45))
		Pattern.FAN:
			var length := fan_spell.projectile_speed * 1.2
			for dir in _fan_directions():
				draw_line(dir * 30.0, dir * length, color, 3.0)
		Pattern.CHARGE:
			var length := charge_speed * charge_max_time
			var side := Vector2(-_attack_dir.y, _attack_dir.x) * body_radius
			var tip := _attack_dir * length
			draw_colored_polygon(PackedVector2Array([side, tip + side, tip - side, -side]), Color(color, color.a * 0.35))
			draw_line(side, tip + side, color, 3.0)
			draw_line(-side, tip - side, color, 3.0)
		Pattern.RING:
			var radius := 120.0 + 110.0 * progress
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 3.0)
			for i in ring_bolts:  # đợt 1 (đậm) và đợt 2 so le nửa bước (nhạt hơn)
				var dir := Vector2.from_angle(TAU * float(i) / float(ring_bolts))
				draw_line(dir * 50.0, dir * radius, Color(color, color.a * 0.8), 2.0)
				var dir2 := Vector2.from_angle(TAU * float(i) / float(ring_bolts) + PI / float(ring_bolts))
				draw_line(dir2 * 50.0, dir2 * radius, Color(color, color.a * 0.4), 2.0)
		Pattern.METEORS:
			pass  # mỗi vùng nổ tự vẽ vòng cảnh báo
		_:
			_draw_extra_telegraph(_pattern, color, progress)


## Vẽ cảnh báo cho đòn riêng của lớp con (mã đòn >= 5). Mặc định không vẽ gì.
func _draw_extra_telegraph(_extra_pattern: int, _color: Color, _progress: float) -> void:
	pass
